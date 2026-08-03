/// Convertidores entre VaultPayload (formato monolítico) y árbol de archivos.
///
/// Round-trip sin pérdida de páginas/bloques: JSON canónico determinista,
/// escritura atómica y sin omitir líneas malformadas al componer.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/errors/vault_corruption_exception.dart';
import '../data/vault_payload.dart';
import '../models/folio_page.dart';
import '../models/folio_page_import_info.dart';
import '../models/block.dart';
import '../models/folio_page_template.dart';
import '../models/local_collab.dart';
import '../models/page_property.dart';
import '../models/jira_integration_state.dart';
import '../models/youtrack_integration_state.dart';
import '../models/trello_integration_state.dart';
import '../models/github_integration_state.dart';
import '../models/gitlab_integration_state.dart';
import '../models/slack_integration_state.dart';
import '../models/teams_integration_state.dart';
import '../models/spotify_integration_state.dart';
import '../models/ytmusic_integration_state.dart';
import '../models/discord_integration_state.dart';
import '../models/system_media_integration_state.dart';
import '../services/ai/ai_types.dart';

/// JSON canónico: keys ordenadas, compacto, vía [jsonEncode] seguro.
String canonicalJson(dynamic obj) {
  return jsonEncode(_sortDeep(obj));
}

dynamic _sortDeep(dynamic obj) {
  if (obj is Map) {
    final keys = obj.keys.map((k) => '$k').toList()..sort();
    return <String, dynamic>{
      for (final k in keys) k: _sortDeep(obj[k]),
    };
  }
  if (obj is List) {
    return obj.map(_sortDeep).toList();
  }
  return obj;
}

Directory _pageDirIn(Directory repoDir, String pageId) {
  final prefix = pageId.length >= 2 ? pageId.substring(0, 2) : 'xx';
  return Directory(p.join(repoDir.path, 'pages', prefix, pageId));
}

Future<void> _writeAtomic(String path, String content) async {
  final file = File(path);
  final dir = file.parent;
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  final tmp = File('$path.tmp');
  await tmp.writeAsString(content, flush: true);
  if (file.existsSync()) {
    await file.delete();
  }
  await tmp.rename(path);
}

/// Descompone VaultPayload al árbol de archivos.
class VaultPayloadToTree {
  static Future<void> decompose(
    VaultPayload payload,
    Directory repoDir,
  ) async {
    if (!repoDir.existsSync()) {
      await repoDir.create(recursive: true);
    }

    await _writeAtomic(
      p.join(repoDir.path, 'tree.json'),
      canonicalJson(payload.pageOrderByParent),
    );

    await _writePages(repoDir, payload);
    await _writeVaultDir(repoDir, payload);
    await _writeAttachmentsManifest(repoDir, payload);
  }

  static Future<void> _writePages(
    Directory repoDir,
    VaultPayload payload,
  ) async {
    final pagesDir = Directory(p.join(repoDir.path, 'pages'));
    if (!pagesDir.existsSync()) {
      await pagesDir.create(recursive: true);
    }

    final writtenPageDirs = <String>{};

    for (final page in payload.pages) {
      final prefix = page.id.length >= 2 ? page.id.substring(0, 2) : 'xx';
      final pageDir = Directory(p.join(pagesDir.path, prefix, page.id));
      if (!pageDir.existsSync()) {
        await pageDir.create(recursive: true);
      }
      writtenPageDirs.add(pageDir.path);

      final meta = {
        'id': page.id,
        'title': page.title,
        if (page.emoji?.isNotEmpty ?? false) 'emoji': page.emoji,
        if (page.parentId != null) 'parentId': page.parentId,
        if (page.isFolder) 'isFolder': true,
        if (page.trashedAt != null)
          'trashedAt': page.trashedAt!.toUtc().toIso8601String(),
        if (page.collabRoomId?.isNotEmpty ?? false)
          'collabRoomId': page.collabRoomId,
        if (page.lastImportInfo != null)
          'lastImportInfo': page.lastImportInfo!.toJson(),
        if (page.properties.isNotEmpty)
          'properties': page.properties.map((prop) => prop.toJson()).toList(),
        if (page.tags.isNotEmpty) 'tags': page.tags,
      };
      await _writeAtomic(
        p.join(pageDir.path, 'meta.json'),
        canonicalJson(meta),
      );

      final blocksFile = File(p.join(pageDir.path, 'blocks.jsonl'));
      final blocksLines =
          page.blocks.map((b) => canonicalJson(b.toJson())).toList();
      if (blocksLines.isNotEmpty) {
        await _writeAtomic(
          blocksFile.path,
          '${blocksLines.join('\n')}\n',
        );
      } else if (blocksFile.existsSync()) {
        await blocksFile.delete();
      }

      final pageComments =
          payload.comments.where((c) => c.pageId == page.id).toList();
      final commentsFile = File(p.join(pageDir.path, 'comments.jsonl'));
      if (pageComments.isNotEmpty) {
        final commentLines =
            pageComments.map((c) => canonicalJson(c.toJson())).toList();
        await _writeAtomic(
          commentsFile.path,
          '${commentLines.join('\n')}\n',
        );
      } else if (commentsFile.existsSync()) {
        await commentsFile.delete();
      }
    }

    // Eliminar páginas stale que ya no están en el payload.
    if (pagesDir.existsSync()) {
      for (final prefixDir in pagesDir.listSync()) {
        if (prefixDir is! Directory) continue;
        for (final pageDir in prefixDir.listSync()) {
          if (pageDir is! Directory) continue;
          if (!writtenPageDirs.contains(pageDir.path)) {
            await pageDir.delete(recursive: true);
          }
        }
        if (prefixDir.listSync().isEmpty) {
          await prefixDir.delete();
        }
      }
    }
  }

  static Future<void> _writeVaultDir(
    Directory repoDir,
    VaultPayload payload,
  ) async {
    final vaultDir = Directory(p.join(repoDir.path, 'vault'));
    if (!vaultDir.existsSync()) {
      await vaultDir.create(recursive: true);
    }

    final meta = {
      'displayName': payload.displayName,
      'aiActiveChatIndex': payload.aiActiveChatIndex,
      'syncClock': payload.syncClock,
      if (payload.pageTombstones.isNotEmpty)
        'pageTombstones': payload.pageTombstones,
      if (payload.mcpReadablePageIds.isNotEmpty)
        'mcpReadablePageIds': payload.mcpReadablePageIds.toList()..sort(),
    };
    await _writeAtomic(
      p.join(vaultDir.path, 'meta.json'),
      canonicalJson(meta),
    );

    if (payload.pageAcl.isNotEmpty) {
      await _writeAtomic(
        p.join(vaultDir.path, 'acl.json'),
        canonicalJson(payload.pageAcl),
      );
    }

    final integDir = Directory(p.join(vaultDir.path, 'integrations'));
    if (!integDir.existsSync()) {
      await integDir.create(recursive: true);
    }

    Future<void> writeInteg(String name, Map<String, dynamic> json) async {
      await _writeAtomic(
        p.join(integDir.path, '$name.json'),
        canonicalJson(json),
      );
    }

    if (payload.jira.connections.isNotEmpty ||
        payload.jira.sources.isNotEmpty) {
      await writeInteg('jira', payload.jira.toJson());
    }
    if (payload.youtrack.connections.isNotEmpty ||
        payload.youtrack.sources.isNotEmpty) {
      await writeInteg('youtrack', payload.youtrack.toJson());
    }
    if (payload.trello.connections.isNotEmpty ||
        payload.trello.sources.isNotEmpty) {
      await writeInteg('trello', payload.trello.toJson());
    }
    if (payload.github.connections.isNotEmpty ||
        payload.github.sources.isNotEmpty) {
      await writeInteg('github', payload.github.toJson());
    }
    if (payload.gitlab.connections.isNotEmpty ||
        payload.gitlab.sources.isNotEmpty) {
      await writeInteg('gitlab', payload.gitlab.toJson());
    }
    if (payload.slack.connections.isNotEmpty) {
      await writeInteg('slack', payload.slack.toJson());
    }
    if (payload.teams.connections.isNotEmpty) {
      await writeInteg('teams', payload.teams.toJson());
    }
    if (payload.spotify.connections.isNotEmpty) {
      await writeInteg('spotify', payload.spotify.toJson());
    }
    if (payload.ytMusic.connections.isNotEmpty) {
      await writeInteg('ytMusic', payload.ytMusic.toJson());
    }
    if (payload.discord.connections.isNotEmpty) {
      await writeInteg('discord', payload.discord.toJson());
    }
    if (payload.systemMedia.enabled || !payload.systemMedia.zenPauseOnExit) {
      await writeInteg('systemMedia', payload.systemMedia.toJson());
    }

    if (payload.pageTemplates.isNotEmpty) {
      final tplDir = Directory(p.join(vaultDir.path, 'templates'));
      if (!tplDir.existsSync()) {
        await tplDir.create(recursive: true);
      }
      for (final tpl in payload.pageTemplates) {
        await _writeAtomic(
          p.join(tplDir.path, '${tpl.id}.json'),
          canonicalJson(tpl.toJson()),
        );
      }
    }

    if (payload.aiChatThreads.isNotEmpty) {
      final chatsDir = Directory(p.join(vaultDir.path, 'ai_chats'));
      if (!chatsDir.existsSync()) {
        await chatsDir.create(recursive: true);
      }
      for (final chat in payload.aiChatThreads) {
        await _writeAtomic(
          p.join(chatsDir.path, '${chat.id}.json'),
          canonicalJson(chat.toJson()),
        );
      }
    }

    if (payload.localProfiles.isNotEmpty) {
      final profDir = Directory(p.join(vaultDir.path, 'profiles'));
      if (!profDir.existsSync()) {
        await profDir.create(recursive: true);
      }
      for (final prof in payload.localProfiles) {
        await _writeAtomic(
          p.join(profDir.path, '${prof.id}.json'),
          canonicalJson(prof.toJson()),
        );
      }
    }
  }

  static Future<void> _writeAttachmentsManifest(
    Directory repoDir,
    VaultPayload payload,
  ) async {
    final paths = <String>{};
    for (final page in payload.pages) {
      for (final block in page.blocks) {
        final url = block.url?.trim() ?? '';
        if (url.startsWith('attachments/')) {
          paths.add(url.replaceAll('\\', '/'));
        }
      }
    }

    final manifest = File(p.join(repoDir.path, 'attachments.manifest.jsonl'));
    if (paths.isEmpty) {
      if (manifest.existsSync()) await manifest.delete();
      return;
    }
    final sortedPaths = paths.toList()..sort();
    final lines = <String>[];
    for (final path in sortedPaths) {
      lines.add(canonicalJson({
        'path': path,
        'sha256': 'sha256-todo-${path.hashCode}',
        'sizeBytes': 0,
      }));
    }
    await _writeAtomic(manifest.path, '${lines.join('\n')}\n');
  }

  /// Escribe meta.json / blocks.jsonl de una página en el árbol.
  static Future<void> writePageFiles(
    Directory repoDir,
    FolioPage page,
  ) async {
    final prefix = page.id.length >= 2 ? page.id.substring(0, 2) : 'xx';
    final pageDir = Directory(
      p.join(repoDir.path, 'pages', prefix, page.id),
    );
    if (!pageDir.existsSync()) {
      await pageDir.create(recursive: true);
    }

    final meta = {
      'id': page.id,
      'title': page.title,
      if (page.emoji?.isNotEmpty ?? false) 'emoji': page.emoji,
      if (page.parentId != null) 'parentId': page.parentId,
      if (page.isFolder) 'isFolder': true,
      if (page.trashedAt != null)
        'trashedAt': page.trashedAt!.toUtc().toIso8601String(),
      if (page.collabRoomId?.isNotEmpty ?? false)
        'collabRoomId': page.collabRoomId,
      if (page.lastImportInfo != null)
        'lastImportInfo': page.lastImportInfo!.toJson(),
      if (page.properties.isNotEmpty)
        'properties': page.properties.map((prop) => prop.toJson()).toList(),
      if (page.tags.isNotEmpty) 'tags': page.tags,
    };
    await _writeAtomic(
      p.join(pageDir.path, 'meta.json'),
      canonicalJson(meta),
    );

    final blocksFile = File(p.join(pageDir.path, 'blocks.jsonl'));
    final blocksLines =
        page.blocks.map((b) => canonicalJson(b.toJson())).toList();
    if (blocksLines.isNotEmpty) {
      await _writeAtomic(blocksFile.path, '${blocksLines.join('\n')}\n');
    } else if (blocksFile.existsSync()) {
      await blocksFile.delete();
    }
  }

  /// Escribe meta.json / blocks.jsonl / comments.jsonl de una sola página,
  /// atómicamente, sin tocar el resto del árbol — para aplicar un pull/merge
  /// incremental por página sin reescribir la libreta entera.
  static Future<void> decomposePage(
    Directory repoDir,
    FolioPage page,
    List<LocalPageComment> allComments,
  ) async {
    await writePageFiles(repoDir, page);
    final pageDir = _pageDirIn(repoDir, page.id);
    final pageComments =
        allComments.where((c) => c.pageId == page.id).toList();
    final commentsFile = File(p.join(pageDir.path, 'comments.jsonl'));
    if (pageComments.isNotEmpty) {
      final commentLines =
          pageComments.map((c) => canonicalJson(c.toJson())).toList();
      await _writeAtomic(commentsFile.path, '${commentLines.join('\n')}\n');
    } else if (commentsFile.existsSync()) {
      await commentsFile.delete();
    }
  }
}

/// Reconstruye VaultPayload desde el árbol de archivos.
class TreeToVaultPayload {
  static Future<VaultPayload> compose(Directory repoDir) async {
    final pageOrderByParent = await _readTreeJson(repoDir);
    final pages = await _readPages(repoDir);
    final vaultMeta = await _readVaultMeta(repoDir);
    final pageAcl = await _readAcl(repoDir);
    final integrations = await _readIntegrations(repoDir);
    final templates = await _readTemplates(repoDir);
    final aiChats = await _readAiChats(repoDir);
    final profiles = await _readProfiles(repoDir);
    final comments = await _readComments(repoDir);

    return VaultPayload(
      version: 15,
      pages: pages,
      displayName: vaultMeta['displayName'] ?? '',
      pageOrderByParent: pageOrderByParent,
      pageRevisions: {},
      pageAcl: pageAcl,
      localProfiles: profiles,
      comments: comments,
      aiChatThreads: aiChats,
      aiActiveChatIndex: vaultMeta['aiActiveChatIndex'] ?? 0,
      pageTemplates: templates,
      jira: integrations['jira'] ?? JiraIntegrationState.empty,
      youtrack: integrations['youtrack'] ?? YouTrackIntegrationState.empty,
      trello: integrations['trello'] ?? TrelloIntegrationState.empty,
      github: integrations['github'] ?? GitHubIntegrationState.empty,
      gitlab: integrations['gitlab'] ?? GitLabIntegrationState.empty,
      slack: integrations['slack'] ?? SlackIntegrationState.empty,
      teams: integrations['teams'] ?? TeamsIntegrationState.empty,
      spotify: integrations['spotify'] ?? SpotifyIntegrationState.empty,
      ytMusic: integrations['ytMusic'] ?? YtMusicIntegrationState.empty,
      discord: integrations['discord'] ?? DiscordIntegrationState.empty,
      systemMedia:
          integrations['systemMedia'] ?? SystemMediaIntegrationState.empty,
      pageTombstones: _parsePageTombstones(vaultMeta['pageTombstones']),
      syncClock: (vaultMeta['syncClock'] as num?)?.toInt() ?? 0,
      mcpReadablePageIds:
          Set<String>.from(vaultMeta['mcpReadablePageIds'] ?? []),
    );
  }

  static Future<Map<String, List<String>>> _readTreeJson(
    Directory repoDir,
  ) async {
    final file = File(p.join(repoDir.path, 'tree.json'));
    if (!file.existsSync()) return {};
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>? ?? {};
    final result = <String, List<String>>{};
    for (final entry in json.entries) {
      final values = entry.value;
      if (values is List) {
        result[entry.key] = values.cast<String>();
      }
    }
    return result;
  }

  static Future<List<FolioPage>> _readPages(Directory repoDir) async {
    final pagesDir = Directory(p.join(repoDir.path, 'pages'));
    if (!pagesDir.existsSync()) return [];

    final pages = <FolioPage>[];
    for (final prefixDir in pagesDir.listSync()) {
      if (prefixDir is! Directory) continue;
      for (final pageDir in prefixDir.listSync()) {
        if (pageDir is! Directory) continue;
        final page = await _readPageDir(pageDir);
        if (page != null) pages.add(page);
      }
    }
    return pages;
  }

  static Future<FolioPage?> _readPageDir(Directory pageDir) async {
    final metaFile = File(p.join(pageDir.path, 'meta.json'));
    final blocksFile = File(p.join(pageDir.path, 'blocks.jsonl'));
    if (!metaFile.existsSync()) {
      if (blocksFile.existsSync()) {
        throw VaultCorruptionException(
          'Page dir ${pageDir.path} has blocks.jsonl without meta.json',
        );
      }
      return null;
    }

    final meta = jsonDecode(await metaFile.readAsString());
    final blocks = await _readBlocksJsonl(pageDir);

    return FolioPage(
      id: meta['id'] ?? 'unknown',
      title: meta['title'] ?? 'Untitled',
      emoji: meta['emoji'],
      parentId: meta['parentId'],
      isFolder: meta['isFolder'] ?? false,
      trashedAt: meta['trashedAt'] != null
          ? DateTime.tryParse(meta['trashedAt'] as String)
          : null,
      collabRoomId: meta['collabRoomId'],
      collabJoinCode: null,
      lastImportInfo: meta['lastImportInfo'] != null
          ? _jsonToImportInfo(meta['lastImportInfo'])
          : null,
      blocks: blocks,
      properties: _parseProperties(meta['properties']),
      tags: ((meta['tags'] ?? []) as List).cast<String>(),
    );
  }

  /// Lee una sola página (y sus comentarios) del árbol sin recorrer el resto
  /// — para aplicar un pull/merge incremental por página.
  static Future<FolioPage?> composePage(
    Directory repoDir,
    String pageId,
  ) async {
    return _readPageDir(_pageDirIn(repoDir, pageId));
  }

  static Future<List<LocalPageComment>> composePageComments(
    Directory repoDir,
    String pageId,
  ) async {
    return _readCommentsInDir(_pageDirIn(repoDir, pageId));
  }

  static Future<List<FolioBlock>> _readBlocksJsonl(Directory pageDir) async {
    final file = File(p.join(pageDir.path, 'blocks.jsonl'));
    if (!file.existsSync()) return [];

    final lines = (await file.readAsString()).split('\n');
    final blocks = <FolioBlock>[];
    var lineNo = 0;
    for (final line in lines) {
      lineNo++;
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line);
        blocks.add(
          FolioBlock.fromJson(Map<String, dynamic>.from(json as Map)),
        );
      } catch (e) {
        throw VaultCorruptionException(
          'Malformed block in ${file.path}:$lineNo',
          cause: e,
        );
      }
    }
    return blocks;
  }

  static Future<Map<String, dynamic>> _readVaultMeta(Directory repoDir) async {
    final file = File(p.join(repoDir.path, 'vault', 'meta.json'));
    if (!file.existsSync()) return {};
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>? ??
        {};
  }

  static Future<Map<String, Map<String, String>>> _readAcl(
    Directory repoDir,
  ) async {
    final file = File(p.join(repoDir.path, 'vault', 'acl.json'));
    if (!file.existsSync()) return {};

    final json = jsonDecode(await file.readAsString());
    return Map<String, Map<String, String>>.from(
      (json as Map?)?.map(
            (k, v) => MapEntry(
              '$k',
              Map<String, String>.from(
                (v as Map?)?.map((k2, v2) => MapEntry('$k2', '$v2')) ?? {},
              ),
            ),
          ) ??
          {},
    );
  }

  static Future<Map<String, dynamic>> _readIntegrations(
    Directory repoDir,
  ) async {
    final dir = Directory(p.join(repoDir.path, 'vault', 'integrations'));
    if (!dir.existsSync()) return {};

    final ints = <String, dynamic>{};
    for (final file in dir.listSync()) {
      if (file is! File || !file.path.endsWith('.json')) continue;

      final name = p.basenameWithoutExtension(file.path);
      final json = jsonDecode(await file.readAsString());

      if (name == 'jira') {
        ints['jira'] = JiraIntegrationState.fromJson(json);
      } else if (name == 'youtrack') {
        ints['youtrack'] = YouTrackIntegrationState.fromJson(json);
      } else if (name == 'trello') {
        ints['trello'] = TrelloIntegrationState.fromJson(json);
      } else if (name == 'github') {
        ints['github'] = GitHubIntegrationState.fromJson(json);
      } else if (name == 'gitlab') {
        ints['gitlab'] = GitLabIntegrationState.fromJson(json);
      } else if (name == 'slack') {
        ints['slack'] = SlackIntegrationState.fromJson(json);
      } else if (name == 'teams') {
        ints['teams'] = TeamsIntegrationState.fromJson(json);
      } else if (name == 'spotify') {
        ints['spotify'] = SpotifyIntegrationState.fromJson(json);
      } else if (name == 'ytMusic') {
        ints['ytMusic'] = YtMusicIntegrationState.fromJson(json);
      } else if (name == 'discord') {
        ints['discord'] = DiscordIntegrationState.fromJson(json);
      } else if (name == 'systemMedia') {
        ints['systemMedia'] = SystemMediaIntegrationState.fromJson(json);
      }
    }
    return ints;
  }

  static Future<List<FolioPageTemplate>> _readTemplates(
    Directory repoDir,
  ) async {
    final dir = Directory(p.join(repoDir.path, 'vault', 'templates'));
    if (!dir.existsSync()) return [];

    final templates = <FolioPageTemplate>[];
    for (final file in dir.listSync()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      final json = jsonDecode(await file.readAsString());
      templates.add(
        FolioPageTemplate.fromJson(Map<String, dynamic>.from(json as Map)),
      );
    }
    return templates;
  }

  static Future<List<AiChatThreadData>> _readAiChats(Directory repoDir) async {
    final dir = Directory(p.join(repoDir.path, 'vault', 'ai_chats'));
    if (!dir.existsSync()) return [];

    final chats = <AiChatThreadData>[];
    for (final file in dir.listSync()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      final json = jsonDecode(await file.readAsString());
      chats.add(
        AiChatThreadData.fromJson(Map<String, dynamic>.from(json as Map)),
      );
    }
    return chats;
  }

  static Future<List<LocalProfile>> _readProfiles(Directory repoDir) async {
    final dir = Directory(p.join(repoDir.path, 'vault', 'profiles'));
    if (!dir.existsSync()) return [];

    final profiles = <LocalProfile>[];
    for (final file in dir.listSync()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      final json = jsonDecode(await file.readAsString());
      profiles.add(
        LocalProfile.fromJson(Map<String, dynamic>.from(json as Map)),
      );
    }
    return profiles;
  }

  static Future<List<LocalPageComment>> _readComments(
    Directory repoDir,
  ) async {
    final comments = <LocalPageComment>[];
    final pagesDir = Directory(p.join(repoDir.path, 'pages'));
    if (!pagesDir.existsSync()) return comments;

    for (final prefixDir in pagesDir.listSync()) {
      if (prefixDir is! Directory) continue;
      for (final pageDir in prefixDir.listSync()) {
        if (pageDir is! Directory) continue;
        comments.addAll(await _readCommentsInDir(pageDir));
      }
    }
    return comments;
  }

  static Future<List<LocalPageComment>> _readCommentsInDir(
    Directory pageDir,
  ) async {
    final comments = <LocalPageComment>[];
    final file = File(p.join(pageDir.path, 'comments.jsonl'));
    if (!file.existsSync()) return comments;

    final lines = (await file.readAsString()).split('\n');
    var lineNo = 0;
    for (final line in lines) {
      lineNo++;
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line);
        comments.add(
          LocalPageComment.fromJson(Map<String, dynamic>.from(json as Map)),
        );
      } catch (e) {
        throw VaultCorruptionException(
          'Malformed comment in ${file.path}:$lineNo',
          cause: e,
        );
      }
    }
    return comments;
  }

  static List<FolioPageProperty> _parseProperties(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => FolioPageProperty.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static FolioPageImportInfo? _jsonToImportInfo(dynamic j) {
    if (j is Map<String, dynamic>) {
      return FolioPageImportInfo.fromJson(j);
    }
    if (j is Map) {
      return FolioPageImportInfo.fromJson(Map<String, dynamic>.from(j));
    }
    return null;
  }

  static Map<String, int> _parsePageTombstones(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map(
      (k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0),
    );
  }
}
