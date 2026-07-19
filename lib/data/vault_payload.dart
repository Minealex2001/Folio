import 'dart:convert';

import '../models/folio_page.dart';
import '../models/folio_page_revision.dart';
import '../models/folio_page_template.dart';
import '../models/jira_integration_state.dart';
import '../models/youtrack_integration_state.dart';
import '../models/trello_integration_state.dart';
import '../models/local_collab.dart';
import '../services/ai/ai_types.dart';

/// Esquema 4: chats de IA. Esquema 5: `FolioPage.collabRoomId` y comentarios de archivo collab.
/// Esquema 6: orden persistido del árbol de páginas (sidebar) por `parentId`.
/// Esquema 7: estado de integraciones nativas (Jira).
/// Esquema 8: papelera de páginas (`FolioPage.trashedAt`).
/// Esquema 9: tombstones de sync multi-dispositivo + `syncClock`.
/// Esquema 10: `displayName` de la libreta (sync multi-dispositivo).
const int kVaultPayloadVersion = 10;

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
    Map<String, int>? pageTombstones,
    this.syncClock = 0,
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
       pageTombstones = pageTombstones ?? const {};

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

  /// Páginas borradas definitivamente: `pageId` → epoch ms UTC del tombstone.
  final Map<String, int> pageTombstones;

  /// Reloj monótono de sync (Lamport ligero) para ordenar revisiones de pack.
  final int syncClock;

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
    if (pageTombstones.isNotEmpty) 'pageTombstones': pageTombstones,
    if (syncClock > 0) 'syncClock': syncClock,
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
      pageTombstones: pageTombstones,
      syncClock: syncClock,
    );
  }

  List<int> encodeUtf8() => utf8.encode(jsonEncode(toJson()));

  static VaultPayload decodeUtf8(List<int> bytes) {
    final s = utf8.decode(bytes);
    final map = jsonDecode(s) as Map<String, dynamic>;
    return VaultPayload.fromJson(map);
  }
}
