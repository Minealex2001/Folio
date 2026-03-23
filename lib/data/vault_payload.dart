import 'dart:convert';

import '../models/folio_page.dart';
import '../models/folio_page_revision.dart';

/// Esquema 2: añade [pageRevisions] (historial por página).
const int kVaultPayloadVersion = 2;

class VaultPayload {
  VaultPayload({
    this.version = kVaultPayloadVersion,
    required this.pages,
    Map<String, List<FolioPageRevision>>? pageRevisions,
  }) : pageRevisions = pageRevisions ?? {};

  final int version;
  final List<FolioPage> pages;
  final Map<String, List<FolioPageRevision>> pageRevisions;

  Map<String, dynamic> toJson() => {
    'version': version,
    'pages': pages.map((p) => p.toJson()).toList(),
    'pageRevisions': pageRevisions.map(
      (k, v) => MapEntry(k, v.map((r) => r.toJson()).toList()),
    ),
  };

  factory VaultPayload.fromJson(Map<String, dynamic> j) {
    final list = (j['pages'] as List<dynamic>? ?? [])
        .map((e) => FolioPage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
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
    return VaultPayload(
      version: j['version'] as int? ?? 1,
      pages: list,
      pageRevisions: pageRevisions,
    );
  }

  List<int> encodeUtf8() => utf8.encode(jsonEncode(toJson()));

  static VaultPayload decodeUtf8(List<int> bytes) {
    final s = utf8.decode(bytes);
    final map = jsonDecode(s) as Map<String, dynamic>;
    return VaultPayload.fromJson(map);
  }
}
