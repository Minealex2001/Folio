/// Fingerprints e integridad round-trip del formato vault v1 (árbol).
///
/// Garantiza que un `decompose` → `compose` no pierda páginas ni bloques
/// (kanban/task incluidos) antes de marcar una migración como éxito o
/// de borrar el blob v0.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/vault_payload.dart';
import '../models/block.dart';
import '../models/folio_page.dart';

/// Resultado de comparar dos fingerprints de contenido de páginas.
class VaultIntegrityMismatch {
  VaultIntegrityMismatch(this.message);
  final String message;

  @override
  String toString() => message;
}

class VaultIntegrity {
  VaultIntegrity._();

  /// Huella estable del contenido vivo de páginas (no incluye pageRevisions;
  /// esas se materializan aparte como snapshots).
  static String fingerprintPages(VaultPayload payload) {
    final pageEntries = <String, String>{};
    for (final page in payload.pages) {
      pageEntries[page.id] = _pageFingerprint(page);
    }
    final sortedIds = pageEntries.keys.toList()..sort();
    final body = <String, Object?>{
      for (final id in sortedIds) id: pageEntries[id],
    };
    return sha256.convert(utf8.encode(jsonEncode(body))).toString();
  }

  static String _pageFingerprint(FolioPage page) {
    final blocks = page.blocks.map(_blockFingerprint).toList();
    final map = <String, Object?>{
      'id': page.id,
      'title': page.title,
      if (page.emoji != null) 'emoji': page.emoji,
      if (page.parentId != null) 'parentId': page.parentId,
      'isFolder': page.isFolder,
      if (page.tags.isNotEmpty) 'tags': List<String>.from(page.tags)..sort(),
      'blocks': blocks,
    };
    return sha256.convert(utf8.encode(jsonEncode(map))).toString();
  }

  static Map<String, Object?> _blockFingerprint(FolioBlock b) {
    return <String, Object?>{
      'id': b.id,
      'type': b.type,
      'text': b.text,
      if (b.richTextDeltaJson != null) 'richTextDeltaJson': b.richTextDeltaJson,
      if (b.checked != null) 'checked': b.checked,
      if (b.expanded != null) 'expanded': b.expanded,
      if (b.codeLanguage != null) 'codeLanguage': b.codeLanguage,
      if (b.codeWrap != null) 'codeWrap': b.codeWrap,
      if (b.depth > 0) 'depth': b.depth,
      if (b.icon != null) 'icon': b.icon,
      if (b.url != null) 'url': b.url,
      if (b.imageWidth != null) 'imageWidth': b.imageWidth,
      if (b.appearance != null && !b.appearance!.isDefault)
        'appearance': b.appearance!.toJson(),
      if (b.meetingNoteProvider != null)
        'meetingNoteProvider': b.meetingNoteProvider,
      if (b.meetingNoteTranscriptionEnabled == false)
        'meetingNoteTranscriptionEnabled': false,
      if (b.syncGroupId != null) 'syncGroupId': b.syncGroupId,
    };
  }

  /// Compara fingerprints; lanza [VaultIntegrityMismatch] si difieren.
  /// También comprueba conteos de páginas/bloques y presencia de ids.
  static void assertPagesMatch(VaultPayload expected, VaultPayload actual) {
    final expIds = expected.pages.map((p) => p.id).toSet();
    final actIds = actual.pages.map((p) => p.id).toSet();
    final missing = expIds.difference(actIds);
    final extra = actIds.difference(expIds);
    if (missing.isNotEmpty || extra.isNotEmpty) {
      throw VaultIntegrityMismatch(
        'Page id mismatch: missing=$missing extra=$extra '
        '(expected ${expIds.length}, got ${actIds.length})',
      );
    }

    final expById = {for (final p in expected.pages) p.id: p};
    final actById = {for (final p in actual.pages) p.id: p};
    for (final id in expIds) {
      final e = expById[id]!;
      final a = actById[id]!;
      if (e.blocks.length != a.blocks.length) {
        throw VaultIntegrityMismatch(
          'Page "$id" (${e.title}): block count '
          '${e.blocks.length} → ${a.blocks.length}',
        );
      }
      final eBlockIds = e.blocks.map((b) => b.id).toSet();
      final aBlockIds = a.blocks.map((b) => b.id).toSet();
      final missB = eBlockIds.difference(aBlockIds);
      if (missB.isNotEmpty) {
        throw VaultIntegrityMismatch(
          'Page "$id" (${e.title}): missing block ids $missB',
        );
      }
      for (var i = 0; i < e.blocks.length; i++) {
        final eb = e.blocks[i];
        final ab = a.blocks.firstWhere((b) => b.id == eb.id);
        if (eb.type != ab.type || eb.text != ab.text) {
          throw VaultIntegrityMismatch(
            'Page "$id" block ${eb.id} type/text changed '
            '(${eb.type}→${ab.type})',
          );
        }
      }
      if (_pageFingerprint(e) != _pageFingerprint(a)) {
        throw VaultIntegrityMismatch(
          'Page "$id" (${e.title}): content fingerprint mismatch',
        );
      }
    }

    final fpExp = fingerprintPages(expected);
    final fpAct = fingerprintPages(actual);
    if (fpExp != fpAct) {
      throw VaultIntegrityMismatch(
        'Payload page fingerprint mismatch: $fpExp ≠ $fpAct',
      );
    }
  }
}
