import 'dart:convert';

import 'block.dart';
import 'folio_page.dart';

/// Instantánea de título + bloques de una página (historial cifrado en el cofre).
class FolioPageRevision {
  FolioPageRevision({
    required this.revisionId,
    required this.savedAtMs,
    required this.title,
    required this.blocksJson,
  });

  final String revisionId;
  final int savedAtMs;
  final String title;
  final List<Map<String, dynamic>> blocksJson;

  /// Huella estable para deduplicar contra otra revisión o el estado actual.
  String contentFingerprint() =>
      jsonEncode({'title': title, 'blocks': blocksJson});

  Map<String, dynamic> toJson() => {
    'revisionId': revisionId,
    'savedAtMs': savedAtMs,
    'title': title,
    'blocks': blocksJson,
  };

  factory FolioPageRevision.fromJson(Map<String, dynamic> j) {
    final blocksRaw = j['blocks'] as List<dynamic>? ?? [];
    return FolioPageRevision(
      revisionId: j['revisionId'] as String? ?? '',
      savedAtMs: j['savedAtMs'] as int? ?? 0,
      title: j['title'] as String? ?? '',
      blocksJson: blocksRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  /// Crea bloques mutables para asignar a [FolioPage.blocks].
  List<FolioBlock> decodeBlocks() =>
      blocksJson.map((m) => FolioBlock.fromJson(m)).toList();
}

/// Huella del contenido versionable de una página (título + bloques).
String folioPageContentFingerprint(FolioPage page) => jsonEncode({
  'title': page.title,
  'blocks': page.blocks.map((b) => b.toJson()).toList(),
});
