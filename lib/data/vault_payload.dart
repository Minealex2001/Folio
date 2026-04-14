import 'dart:convert';

import '../models/folio_page.dart';
import '../models/folio_page_revision.dart';
import '../models/folio_page_template.dart';
import '../models/local_collab.dart';
import '../services/ai/ai_types.dart';

/// Esquema 4: chats de IA. Esquema 5: `FolioPage.collabRoomId` y comentarios de archivo collab.
/// Esquema 6: orden persistido del árbol de páginas (sidebar) por `parentId`.
const int kVaultPayloadVersion = 6;

class VaultPayload {
  VaultPayload({
    this.version = kVaultPayloadVersion,
    required this.pages,
    Map<String, List<String>>? pageOrderByParent,
    Map<String, List<FolioPageRevision>>? pageRevisions,
    Map<String, Map<String, String>>? pageAcl,
    List<LocalProfile>? localProfiles,
    List<LocalPageComment>? comments,
    List<AiChatThreadData>? aiChatThreads,
    int? aiActiveChatIndex,
    List<FolioPageTemplate>? pageTemplates,
  }) : pageRevisions = pageRevisions ?? {},
       pageAcl = pageAcl ?? {},
       pageOrderByParent = pageOrderByParent ?? {},
       localProfiles = localProfiles ?? const [],
       comments = comments ?? const [],
       aiChatThreads = aiChatThreads ?? const [],
       aiActiveChatIndex = aiActiveChatIndex ?? 0,
       pageTemplates = pageTemplates ?? const [];

  final int version;
  final List<FolioPage> pages;
  /// Orden del árbol por `parentId`. La raíz se guarda como clave vacía `''`.
  final Map<String, List<String>> pageOrderByParent;
  final Map<String, List<FolioPageRevision>> pageRevisions;
  final Map<String, Map<String, String>> pageAcl;
  final List<LocalProfile> localProfiles;
  final List<LocalPageComment> comments;
  final List<AiChatThreadData> aiChatThreads;
  final int aiActiveChatIndex;
  final List<FolioPageTemplate> pageTemplates;

  Map<String, dynamic> toJson() => {
    'version': version,
    'pages': pages.map((p) => p.toJson()).toList(),
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
        final key = e.key as String;
        final rawList = e.value as List<dynamic>? ?? [];
        pageRevisions[key] = rawList
            .map(
              (x) => FolioPageRevision.fromJson(
                Map<String, dynamic>.from(x as Map),
              ),
            )
            .toList();
      }
    }
    final acl = <String, Map<String, String>>{};
    final rawAcl = j['pageAcl'];
    if (rawAcl is Map) {
      for (final e in rawAcl.entries) {
        acl[e.key as String] = Map<String, String>.from(
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
    return VaultPayload(
      version: j['version'] as int? ?? 1,
      pages: list,
      pageOrderByParent: pageOrderByParent,
      pageRevisions: pageRevisions,
      pageAcl: acl,
      localProfiles: profiles,
      comments: comments,
      aiChatThreads: aiThreads,
      aiActiveChatIndex: aiIndex,
      pageTemplates: templates,
    );
  }

  List<int> encodeUtf8() => utf8.encode(jsonEncode(toJson()));

  static VaultPayload decodeUtf8(List<int> bytes) {
    final s = utf8.decode(bytes);
    final map = jsonDecode(s) as Map<String, dynamic>;
    return VaultPayload.fromJson(map);
  }
}
