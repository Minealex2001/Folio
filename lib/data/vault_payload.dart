import 'dart:convert';

import '../models/folio_page.dart';
import '../models/folio_page_revision.dart';
import '../models/folio_page_template.dart';
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
import '../models/local_collab.dart';
import '../services/ai/ai_types.dart';

/// Esquema 4: chats de IA. Esquema 5: `FolioPage.collabRoomId` y comentarios de archivo collab.
/// Esquema 6: orden persistido del árbol de páginas (sidebar) por `parentId`.
/// Esquema 7: estado de integraciones nativas (Jira).
/// Esquema 8: papelera de páginas (`FolioPage.trashedAt`).
/// Esquema 9: tombstones de sync multi-dispositivo + `syncClock`.
/// Esquema 10: `displayName` de la libreta (sync multi-dispositivo).
/// Esquema 11: allowlist MCP de páginas legibles (`mcpReadablePageIds`).
/// Esquema 12: estado de integraciones Slack y Microsoft Teams (notificaciones vía webhook).
/// Esquema 13: integración Spotify (OAuth, reproducción, modo zen).
/// Esquema 14: integración Discord (Incoming Webhook).
/// Esquema 15: media del sistema (SMTC / MediaSession / MPRIS).
/// Esquema 16: integración YouTube Music (OAuth device-flow / InnerTube).
const int kVaultPayloadVersion = 16;

class VaultPayload {
  VaultPayload({
    this.version = kVaultPayloadVersion,
    required this.pages,
    this.displayName = '',
    Map<String, List<String>>? pageOrderByParent,
    Map<String, List<FolioPageRevision>>? pageRevisions,
    Map<String, Map<String, String>>? pageAcl,
    List<LocalProfile>? localProfiles,
    List<LocalPageComment>? comments,
    List<AiChatThreadData>? aiChatThreads,
    int? aiActiveChatIndex,
    List<FolioPageTemplate>? pageTemplates,
    JiraIntegrationState? jira,
    YouTrackIntegrationState? youtrack,
    TrelloIntegrationState? trello,
    GitHubIntegrationState? github,
    GitLabIntegrationState? gitlab,
    SlackIntegrationState? slack,
    TeamsIntegrationState? teams,
    SpotifyIntegrationState? spotify,
    YtMusicIntegrationState? ytMusic,
    DiscordIntegrationState? discord,
    SystemMediaIntegrationState? systemMedia,
    Map<String, int>? pageTombstones,
    this.syncClock = 0,
    Set<String>? mcpReadablePageIds,
  }) : pageRevisions = pageRevisions ?? {},
       pageAcl = pageAcl ?? {},
       pageOrderByParent = pageOrderByParent ?? {},
       localProfiles = localProfiles ?? const [],
       comments = comments ?? const [],
       aiChatThreads = aiChatThreads ?? const [],
       aiActiveChatIndex = aiActiveChatIndex ?? 0,
       pageTemplates = pageTemplates ?? const [],
       jira = jira ?? JiraIntegrationState.empty,
       youtrack = youtrack ?? YouTrackIntegrationState.empty,
       trello = trello ?? TrelloIntegrationState.empty,
       github = github ?? GitHubIntegrationState.empty,
       gitlab = gitlab ?? GitLabIntegrationState.empty,
       slack = slack ?? SlackIntegrationState.empty,
       teams = teams ?? TeamsIntegrationState.empty,
       spotify = spotify ?? SpotifyIntegrationState.empty,
       ytMusic = ytMusic ?? YtMusicIntegrationState.empty,
       discord = discord ?? DiscordIntegrationState.empty,
       systemMedia = systemMedia ?? SystemMediaIntegrationState.empty,
       pageTombstones = pageTombstones ?? const {},
       mcpReadablePageIds = Set<String>.of(mcpReadablePageIds ?? const <String>{});

  final int version;
  final List<FolioPage> pages;
  /// Nombre visible de la libreta (sincronizado entre dispositivos).
  final String displayName;
  /// Orden del árbol por `parentId`. La raíz se guarda como clave vacía `''`.
  final Map<String, List<String>> pageOrderByParent;
  final Map<String, List<FolioPageRevision>> pageRevisions;
  final Map<String, Map<String, String>> pageAcl;
  final List<LocalProfile> localProfiles;
  final List<LocalPageComment> comments;
  final List<AiChatThreadData> aiChatThreads;
  final int aiActiveChatIndex;
  final List<FolioPageTemplate> pageTemplates;
  final JiraIntegrationState jira;
  final YouTrackIntegrationState youtrack;
  final TrelloIntegrationState trello;
  final GitHubIntegrationState github;
  final GitLabIntegrationState gitlab;
  final SlackIntegrationState slack;
  final TeamsIntegrationState teams;
  final SpotifyIntegrationState spotify;
  final YtMusicIntegrationState ytMusic;
  final DiscordIntegrationState discord;
  final SystemMediaIntegrationState systemMedia;

  /// Páginas borradas definitivamente: `pageId` → epoch ms UTC del tombstone.
  final Map<String, int> pageTombstones;

  /// Reloj monótono de sync (Lamport ligero) para ordenar revisiones de pack.
  final int syncClock;

  /// Ids de páginas/carpetas que el servidor MCP puede leer (allowlist).
  /// Si una carpeta está en el set, sus descendientes también son legibles.
  final Set<String> mcpReadablePageIds;

  Map<String, dynamic> toJson() => {
    'version': version,
    'pages': pages.map((p) => p.toJson()).toList(),
    if (displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
    if (pageOrderByParent.isNotEmpty) 'pageOrderByParent': pageOrderByParent,
    'pageRevisions': pageRevisions.map(
      (k, v) => MapEntry(k, v.map((r) => r.toJson()).toList()),
    ),
    'pageAcl': pageAcl,
    'localProfiles': localProfiles.map((p) => p.toJson()).toList(),
    'comments': comments.map((c) => c.toJson()).toList(),
    'aiChatThreads': aiChatThreads.map((t) => t.toJson()).toList(),
    'aiActiveChatIndex': aiActiveChatIndex,
    if (pageTemplates.isNotEmpty)
      'pageTemplates': pageTemplates.map((t) => t.toJson()).toList(),
    if (jira.connections.isNotEmpty || jira.sources.isNotEmpty) 'jira': jira.toJson(),
    if (youtrack.connections.isNotEmpty || youtrack.sources.isNotEmpty)
      'youtrack': youtrack.toJson(),
    if (trello.connections.isNotEmpty || trello.sources.isNotEmpty)
      'trello': trello.toJson(),
    if (github.connections.isNotEmpty || github.sources.isNotEmpty)
      'github': github.toJson(),
    if (gitlab.connections.isNotEmpty || gitlab.sources.isNotEmpty)
      'gitlab': gitlab.toJson(),
    if (slack.connections.isNotEmpty) 'slack': slack.toJson(),
    if (teams.connections.isNotEmpty) 'teams': teams.toJson(),
    if (spotify.connections.isNotEmpty) 'spotify': spotify.toJson(),
    if (ytMusic.connections.isNotEmpty) 'ytMusic': ytMusic.toJson(),
    if (discord.connections.isNotEmpty) 'discord': discord.toJson(),
    if (systemMedia.enabled || !systemMedia.zenPauseOnExit)
      'systemMedia': systemMedia.toJson(),
    if (pageTombstones.isNotEmpty) 'pageTombstones': pageTombstones,
    if (syncClock > 0) 'syncClock': syncClock,
    if (mcpReadablePageIds.isNotEmpty)
      'mcpReadablePageIds': mcpReadablePageIds.toList(growable: false),
  };

  factory VaultPayload.fromJson(Map<String, dynamic> j) {
    final list = (j['pages'] as List<dynamic>? ?? [])
        .map((e) => FolioPage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final pageOrderByParent = <String, List<String>>{};
    final rawOrder = j['pageOrderByParent'];
    if (rawOrder is Map) {
      for (final entry in rawOrder.entries) {
        final key = '${entry.key}';
        final v = entry.value;
        if (v is List) {
          pageOrderByParent[key] = v.map((x) => '$x').toList(growable: false);
        }
      }
    }
    final revRoot = j['pageRevisions'];
    final pageRevisions = <String, List<FolioPageRevision>>{};
    if (revRoot is Map) {
      for (final e in revRoot.entries) {
        final key = '${e.key}';
        final rawList = e.value is List ? e.value as List<dynamic> : const [];
        pageRevisions[key] = rawList
            .whereType<Map>()
            .map(
              (x) => FolioPageRevision.fromJson(
                Map<String, dynamic>.from(x),
              ),
            )
            .toList();
      }
    }
    final acl = <String, Map<String, String>>{};
    final rawAcl = j['pageAcl'];
    if (rawAcl is Map) {
      for (final e in rawAcl.entries) {
        acl['${e.key}'] = Map<String, String>.from(
          (e.value as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
        );
      }
    }
    final profiles = (j['localProfiles'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => LocalProfile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final comments = (j['comments'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => LocalPageComment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final aiThreads = (j['aiChatThreads'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => AiChatThreadData.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final aiIndex = (j['aiActiveChatIndex'] as num?)?.toInt() ?? 0;
    final templates = (j['pageTemplates'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => FolioPageTemplate.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.id.isNotEmpty)
        .toList();
    final jira = JiraIntegrationState.fromJson(j['jira']);
    final youtrack = YouTrackIntegrationState.fromJson(j['youtrack']);
    final trello = TrelloIntegrationState.fromJson(j['trello']);
    final github = GitHubIntegrationState.fromJson(j['github']);
    final gitlab = GitLabIntegrationState.fromJson(j['gitlab']);
    final slack = SlackIntegrationState.fromJson(j['slack']);
    final teams = TeamsIntegrationState.fromJson(j['teams']);
    final spotify = SpotifyIntegrationState.fromJson(j['spotify']);
    final ytMusic = YtMusicIntegrationState.fromJson(j['ytMusic']);
    final discord = DiscordIntegrationState.fromJson(j['discord']);
    final systemMedia = SystemMediaIntegrationState.fromJson(j['systemMedia']);
    final pageTombstones = <String, int>{};
    final rawTombs = j['pageTombstones'];
    if (rawTombs is Map) {
      for (final e in rawTombs.entries) {
        final key = '${e.key}'.trim();
        if (key.isEmpty) continue;
        final v = e.value;
        if (v is num) {
          pageTombstones[key] = v.toInt();
        } else if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) pageTombstones[key] = parsed;
        }
      }
    }
    final syncClock = (j['syncClock'] as num?)?.toInt() ?? 0;
    final displayName = '${j['displayName'] ?? ''}'.trim();
    final mcpReadablePageIds = <String>{};
    final rawMcpReadable = j['mcpReadablePageIds'];
    if (rawMcpReadable is List) {
      for (final e in rawMcpReadable) {
        final id = '$e'.trim();
        if (id.isNotEmpty) mcpReadablePageIds.add(id);
      }
    }
    return VaultPayload(
      version: j['version'] as int? ?? 1,
      pages: list,
      displayName: displayName,
      pageOrderByParent: pageOrderByParent,
      pageRevisions: pageRevisions,
      pageAcl: acl,
      localProfiles: profiles,
      comments: comments,
      aiChatThreads: aiThreads,
      aiActiveChatIndex: aiIndex,
      pageTemplates: templates,
      jira: jira,
      youtrack: youtrack,
      trello: trello,
      github: github,
      gitlab: gitlab,
      slack: slack,
      teams: teams,
      spotify: spotify,
      ytMusic: ytMusic,
      discord: discord,
      systemMedia: systemMedia,
      pageTombstones: pageTombstones,
      syncClock: syncClock,
      mcpReadablePageIds: mcpReadablePageIds,
    );
  }

  List<int> encodeUtf8() => utf8.encode(jsonEncode(toJson()));

  static VaultPayload decodeUtf8(List<int> bytes) {
    final s = utf8.decode(bytes);
    final map = jsonDecode(s) as Map<String, dynamic>;
    return VaultPayload.fromJson(map);
  }

  /// JSON de una sola página + sus comentarios, como unidad autocontenida
  /// para direccionar por contenido en sync incremental (cada página es su
  /// propio blob, igual que ya se hace con los adjuntos).
  static Map<String, dynamic> pageSliceJson(
    FolioPage page,
    List<LocalPageComment> allComments,
  ) => {
    'page': page.toJson(),
    'comments': allComments
        .where((c) => c.pageId == page.id)
        .map((c) => c.toJson())
        .toList(),
  };

  /// JSON del payload completo sin `pages` (quedan aparte, direccionadas por
  /// contenido individualmente). Los comentarios de página van con su página
  /// vía [pageSliceJson]; los huérfanos (pageId sin página viva) se conservan
  /// aquí para no perderlos. Se construye a partir de [toJson] en vez de
  /// re-listar campos a mano, para no arriesgarse a olvidar uno nuevo.
  Map<String, dynamic> restJsonExcludingPages() {
    final livePageIds = pages.map((p) => p.id).toSet();
    final json = Map<String, dynamic>.from(toJson());
    json.remove('pages');
    json['comments'] = comments
        .where((c) => !livePageIds.contains(c.pageId))
        .map((c) => c.toJson())
        .toList();
    return json;
  }

  /// Inversa de [restJsonExcludingPages] + [pageSliceJson]: reconstruye el
  /// JSON completo del payload a partir del "resto" y las páginas sueltas.
  static Map<String, dynamic> mergeRestAndPageSlices(
    Map<String, dynamic> restJson,
    List<Map<String, dynamic>> pageSlices,
  ) {
    final json = Map<String, dynamic>.from(restJson);
    final pagesJson = <dynamic>[];
    final commentsJson = List<dynamic>.from(
      restJson['comments'] as List? ?? const [],
    );
    for (final slice in pageSlices) {
      pagesJson.add(slice['page']);
      final sliceComments = slice['comments'];
      if (sliceComments is List) commentsJson.addAll(sliceComments);
    }
    json['pages'] = pagesJson;
    json['comments'] = commentsJson;
    return json;
  }
}
