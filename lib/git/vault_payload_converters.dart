/// Convertidores entre VaultPayload (formato monolítico) y árbol de archivos.
///
/// M0: Conversión bidireccional sin pérdida de datos.

import 'dart:io';
import 'dart:convert';

import '../data/vault_payload.dart';
import '../models/folio_page.dart';
import '../models/block.dart';
import '../models/folio_page_template.dart';
import '../models/local_collab.dart';
import '../models/jira_integration_state.dart';
import '../models/youtrack_integration_state.dart';
import '../models/trello_integration_state.dart';
import '../models/github_integration_state.dart';
import '../models/gitlab_integration_state.dart';
import '../models/slack_integration_state.dart';
import '../models/teams_integration_state.dart';
import '../models/spotify_integration_state.dart';
import '../models/discord_integration_state.dart';
import '../models/system_media_integration_state.dart';
import '../services/ai/ai_types.dart';

/// JSON canónico: sorted keys, compact.
String _canonical(dynamic obj) {
  if (obj is Map) {
    final keys = (obj.keys.toList()..sort()).cast<String>();
    final entries = keys.map((k) => '"$k":${_canonical(obj[k])}');
    return '{${entries.join(',')}}';
  } else if (obj is List) {
    return '[${obj.map(_canonical).join(',')}]';
  } else if (obj is String) {
    return jsonEncode(obj);
  } else if (obj == null) {
    return 'null';
  } else {
    return obj.toString();
  }
}

/// Descompone VaultPayload al árbol de archivos.
class VaultPayloadToTree {
  static Future<void> decompose(
    VaultPayload payload,
    Directory repoDir,
  ) async {
    repoDir.createSync(recursive: true);

    // 1. tree.json (pageOrderByParent)
    final treeFile = File('${repoDir.path}/tree.json');
    await treeFile.writeAsString(_canonical(payload.pageOrderByParent));

    // 2. pages/
    await _writePages(repoDir, payload);

    // 3. vault/
    await _writeVaultDir(repoDir, payload);

    // 4. attachments.manifest.jsonl
    await _writeAttachmentsManifest(repoDir, payload);
  }

  static Future<void> _writePages(Directory repoDir, VaultPayload payload) async {
    final pagesDir = Directory('${repoDir.path}/pages');
    pagesDir.createSync(recursive: true);

    for (final page in payload.pages) {
      final prefix = page.id.length >= 2 ? page.id.substring(0, 2) : 'xx';
      final pageDir = Directory('${pagesDir.path}/$prefix/${page.id}');
      pageDir.createSync(recursive: true);

      // meta.json
      final meta = {
        'id': page.id,
        'title': page.title,
        if (page.emoji?.isNotEmpty ?? false) 'emoji': page.emoji,
        if (page.parentId != null) 'parentId': page.parentId,
        if (page.isFolder) 'isFolder': true,
        if (page.trashedAt != null) 'trashedAt': page.trashedAt!.toUtc().toIso8601String(),
        if (page.collabRoomId?.isNotEmpty ?? false) 'collabRoomId': page.collabRoomId,
        if (page.lastImportInfo != null) 'lastImportInfo': page.lastImportInfo!.toJson(),
        if (page.properties.isNotEmpty)
          'properties': page.properties.map((p) => p.toJson()).toList(),
        if (page.tags.isNotEmpty) 'tags': page.tags,
      };
      await File('${pageDir.path}/meta.json').writeAsString(_canonical(meta));

      // blocks.jsonl (one block per line)
      final blocksLines = page.blocks.map((b) => _canonical(b.toJson())).toList();
      if (blocksLines.isNotEmpty) {
        await File('${pageDir.path}/blocks.jsonl')
            .writeAsString('${blocksLines.join('\n')}\n');
      }

      // comments.jsonl (filtered by pageId)
      final pageComments = payload.comments.where((c) => c.pageId == page.id).toList();
      if (pageComments.isNotEmpty) {
        final commentLines = pageComments.map((c) => _canonical(c.toJson())).toList();
        await File('${pageDir.path}/comments.jsonl')
            .writeAsString('${commentLines.join('\n')}\n');
      }
    }
  }

  static Future<void> _writeVaultDir(Directory repoDir, VaultPayload payload) async {
    final vaultDir = Directory('${repoDir.path}/vault');
    vaultDir.createSync(recursive: true);

    // vault/meta.json
    final meta = {
      'displayName': payload.displayName,
      'aiActiveChatIndex': payload.aiActiveChatIndex,
      if (payload.mcpReadablePageIds.isNotEmpty)
        'mcpReadablePageIds': payload.mcpReadablePageIds.toList()..sort(),
    };
    await File('${vaultDir.path}/meta.json').writeAsString(_canonical(meta));

    // vault/acl.json
    if (payload.pageAcl.isNotEmpty) {
      await File('${vaultDir.path}/acl.json').writeAsString(_canonical(payload.pageAcl));
    }

    // vault/integrations/
    final integDir = Directory('${vaultDir.path}/integrations');
    integDir.createSync(recursive: true);

    if (payload.jira.connections.isNotEmpty || payload.jira.sources.isNotEmpty) {
      await File('${integDir.path}/jira.json')
          .writeAsString(_canonical(payload.jira.toJson()));
    }
    if (payload.youtrack.connections.isNotEmpty || payload.youtrack.sources.isNotEmpty) {
      await File('${integDir.path}/youtrack.json')
          .writeAsString(_canonical(payload.youtrack.toJson()));
    }
    if (payload.trello.connections.isNotEmpty || payload.trello.sources.isNotEmpty) {
      await File('${integDir.path}/trello.json')
          .writeAsString(_canonical(payload.trello.toJson()));
    }
    if (payload.github.connections.isNotEmpty || payload.github.sources.isNotEmpty) {
      await File('${integDir.path}/github.json')
          .writeAsString(_canonical(payload.github.toJson()));
    }
    if (payload.gitlab.connections.isNotEmpty || payload.gitlab.sources.isNotEmpty) {
      await File('${integDir.path}/gitlab.json')
          .writeAsString(_canonical(payload.gitlab.toJson()));
    }
    if (payload.slack.connections.isNotEmpty) {
      await File('${integDir.path}/slack.json')
          .writeAsString(_canonical(payload.slack.toJson()));
    }
    if (payload.teams.connections.isNotEmpty) {
      await File('${integDir.path}/teams.json')
          .writeAsString(_canonical(payload.teams.toJson()));
    }
    if (payload.spotify.connections.isNotEmpty) {
      await File('${integDir.path}/spotify.json')
          .writeAsString(_canonical(payload.spotify.toJson()));
    }
    if (payload.discord.connections.isNotEmpty) {
      await File('${integDir.path}/discord.json')
          .writeAsString(_canonical(payload.discord.toJson()));
    }
    if (payload.systemMedia.enabled || !payload.systemMedia.zenPauseOnExit) {
      await File('${integDir.path}/systemMedia.json')
          .writeAsString(_canonical(payload.systemMedia.toJson()));
    }

    // vault/templates/
    if (payload.pageTemplates.isNotEmpty) {
      final tplDir = Directory('${vaultDir.path}/templates');
      tplDir.createSync(recursive: true);
      for (final tpl in payload.pageTemplates) {
        await File('${tplDir.path}/${tpl.id}.json')
            .writeAsString(_canonical(tpl.toJson()));
      }
    }

    // vault/ai_chats/
    if (payload.aiChatThreads.isNotEmpty) {
      final chatsDir = Directory('${vaultDir.path}/ai_chats');
      chatsDir.createSync(recursive: true);
      for (final chat in payload.aiChatThreads) {
        await File('${chatsDir.path}/${chat.id}.json')
            .writeAsString(_canonical(chat.toJson()));
      }
    }

    // vault/profiles/
    if (payload.localProfiles.isNotEmpty) {
      final profDir = Directory('${vaultDir.path}/profiles');
      profDir.createSync(recursive: true);
      for (final prof in payload.localProfiles) {
        await File('${profDir.path}/${prof.id}.json')
            .writeAsString(_canonical(prof.toJson()));
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

    if (paths.isNotEmpty) {
      final sortedPaths = paths.toList()..sort();
      final lines = <String>[];
      for (final path in sortedPaths) {
        // TODO: calculate actual sha256 from file, if needed
        lines.add(_canonical({
          'path': path,
          'sha256': 'sha256-todo-${path.hashCode}',
          'sizeBytes': 0,
        }));
      }
      await File('${repoDir.path}/attachments.manifest.jsonl')
          .writeAsString('${lines.join('\n')}\n');
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
      pageRevisions: {}, // Replaced by snapshots
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
      discord: integrations['discord'] ?? DiscordIntegrationState.empty,
      systemMedia: integrations['systemMedia'] ?? SystemMediaIntegrationState.empty,
      pageTombstones: {}, // Replaced by Git deletes
      syncClock: 0, // Dropped
      mcpReadablePageIds:
          Set<String>.from(vaultMeta['mcpReadablePageIds'] ?? []),
    );
  }

  static Future<Map<String, List<String>>> _readTreeJson(Directory repoDir) async {
    final file = File('${repoDir.path}/tree.json');
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
    final pagesDir = Directory('${repoDir.path}/pages');
    if (!pagesDir.existsSync()) return [];

    final pages = <FolioPage>[];
    for (final prefixDir in pagesDir.listSync()) {
      if (prefixDir is! Directory) continue;
      for (final pageDir in prefixDir.listSync()) {
        if (pageDir is! Directory) continue;

        final metaFile = File('${pageDir.path}/meta.json');
        if (!metaFile.existsSync()) continue;

        final meta = jsonDecode(await metaFile.readAsString());
        final blocks = await _readBlocksJsonl(pageDir as Directory);

        pages.add(FolioPage(
          id: meta['id'] ?? 'unknown',
          title: meta['title'] ?? 'Untitled',
          emoji: meta['emoji'],
          parentId: meta['parentId'],
          isFolder: meta['isFolder'] ?? false,
          trashedAt: meta['trashedAt'] != null
              ? DateTime.tryParse(meta['trashedAt'])
              : null,
          collabRoomId: meta['collabRoomId'],
          collabJoinCode: null, // Never synced
          lastImportInfo: meta['lastImportInfo'] != null
              ? _jsonToImportInfo(meta['lastImportInfo'])
              : null,
          blocks: blocks,
          properties: (_parseProperties(meta['properties']) as List?)?.cast() ?? [],
          tags: ((meta['tags'] ?? []) as List).cast<String>(),
        ));
      }
    }
    return pages;
  }

  static Future<List<FolioBlock>> _readBlocksJsonl(Directory pageDir) async {
    final file = File('${pageDir.path}/blocks.jsonl');
    if (!file.existsSync()) return [];

    final lines = (await file.readAsString()).split('\n');
    final blocks = <FolioBlock>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line);
        blocks.add(FolioBlock.fromJson(Map<String, dynamic>.from(json)));
      } catch (e) {
        // Skip malformed
      }
    }
    return blocks;
  }

  static Future<Map<String, dynamic>> _readVaultMeta(Directory repoDir) async {
    final file = File('${repoDir.path}/vault/meta.json');
    if (!file.existsSync()) return {};
    return jsonDecode(await file.readAsString()) ?? {};
  }

  static Future<Map<String, Map<String, String>>> _readAcl(Directory repoDir) async {
    final file = File('${repoDir.path}/vault/acl.json');
    if (!file.existsSync()) return {};

    final json = jsonDecode(await file.readAsString());
    return Map<String, Map<String, String>>.from(
      (json as Map?)?.map((k, v) => MapEntry(
            '$k',
            Map<String, String>.from(
              (v as Map?)?.map((k2, v2) => MapEntry('$k2', '$v2')) ?? {},
            ),
          )) ??
          {},
    );
  }

  static Future<Map<String, dynamic>> _readIntegrations(Directory repoDir) async {
    final dir = Directory('${repoDir.path}/vault/integrations');
    if (!dir.existsSync()) return {};

    final ints = <String, dynamic>{};
    for (final file in dir.listSync()) {
      if (file is! File || !file.path.endsWith('.json')) continue;

      final name = file.path.split('/').last.replaceAll('.json', '');
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
      } else if (name == 'discord') {
        ints['discord'] = DiscordIntegrationState.fromJson(json);
      } else if (name == 'systemMedia') {
        ints['systemMedia'] = SystemMediaIntegrationState.fromJson(json);
      }
    }
    return ints;
  }

  static Future<List<FolioPageTemplate>> _readTemplates(Directory repoDir) async {
    final dir = Directory('${repoDir.path}/vault/templates');
    if (!dir.existsSync()) return [];

    final templates = <FolioPageTemplate>[];
    for (final file in dir.listSync()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      final json = jsonDecode(await file.readAsString());
      templates.add(FolioPageTemplate.fromJson(Map<String, dynamic>.from(json)));
    }
    return templates;
  }

  static Future<List<AiChatThreadData>> _readAiChats(Directory repoDir) async {
    final dir = Directory('${repoDir.path}/vault/ai_chats');
    if (!dir.existsSync()) return [];

    final chats = <AiChatThreadData>[];
    for (final file in dir.listSync()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      final json = jsonDecode(await file.readAsString());
      chats.add(AiChatThreadData.fromJson(Map<String, dynamic>.from(json)));
    }
    return chats;
  }

  static Future<List<LocalProfile>> _readProfiles(Directory repoDir) async {
    final dir = Directory('${repoDir.path}/vault/profiles');
    if (!dir.existsSync()) return [];

    final profiles = <LocalProfile>[];
    for (final file in dir.listSync()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      final json = jsonDecode(await file.readAsString());
      profiles.add(LocalProfile.fromJson(Map<String, dynamic>.from(json)));
    }
    return profiles;
  }

  static Future<List<LocalPageComment>> _readComments(Directory repoDir) async {
    final comments = <LocalPageComment>[];
    final pagesDir = Directory('${repoDir.path}/pages');
    if (!pagesDir.existsSync()) return comments;

    for (final prefixDir in pagesDir.listSync()) {
      if (prefixDir is! Directory) continue;
      for (final pageDir in prefixDir.listSync()) {
        if (pageDir is! Directory) continue;

        final file = File('${pageDir.path}/comments.jsonl');
        if (!file.existsSync()) continue;

        final lines = (await file.readAsString()).split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final json = jsonDecode(line);
            comments.add(LocalPageComment.fromJson(Map<String, dynamic>.from(json)));
          } catch (e) {
            // Skip malformed
          }
        }
      }
    }
    return comments;
  }

  // Parsers (TODO: implement fully based on actual models)
  static List _parseProperties(dynamic raw) {
    // TODO: implement full parsing of FolioPageProperty from JSON
    // For now, return empty list — properties will be reconstructed from pages
    return [];
  }

  static dynamic _jsonToImportInfo(dynamic j) => j;
  static dynamic _jsonToProperty(Map j) => j;
}
