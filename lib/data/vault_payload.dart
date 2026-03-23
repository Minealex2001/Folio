import 'dart:convert';

import '../models/folio_page.dart';

class VaultPayload {
  VaultPayload({
    this.version = 1,
    required this.pages,
  });

  final int version;
  final List<FolioPage> pages;

  Map<String, dynamic> toJson() => {
        'version': version,
        'pages': pages.map((p) => p.toJson()).toList(),
      };

  factory VaultPayload.fromJson(Map<String, dynamic> j) {
    final list = (j['pages'] as List<dynamic>? ?? [])
        .map((e) => FolioPage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return VaultPayload(
      version: j['version'] as int? ?? 1,
      pages: list,
    );
  }

  List<int> encodeUtf8() => utf8.encode(jsonEncode(toJson()));

  static VaultPayload decodeUtf8(List<int> bytes) {
    final s = utf8.decode(bytes);
    final map = jsonDecode(s) as Map<String, dynamic>;
    return VaultPayload.fromJson(map);
  }
}
