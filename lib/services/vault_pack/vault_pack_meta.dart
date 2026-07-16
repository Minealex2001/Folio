import 'dart:convert';

/// Metadatos del pack incremental en carpeta/WebDAV (`meta.json`).
class VaultPackMeta {
  const VaultPackMeta({
    required this.formatVersion,
    required this.contentFingerprint,
    required this.headSnapshot,
    required this.updatedAtUtc,
    this.snapshotSizeBytes = 0,
    this.hasRestoreWrap = false,
    this.wrapKind,
    this.snapshots = const [],
  });

  static const int currentFormatVersion = 1;

  final int formatVersion;
  final String contentFingerprint;
  final String headSnapshot;
  final String updatedAtUtc;
  final int snapshotSizeBytes;
  final bool hasRestoreWrap;
  final String? wrapKind;
  final List<VaultPackSnapshotRef> snapshots;

  Map<String, Object?> toJson() => <String, Object?>{
        'formatVersion': formatVersion,
        'contentFingerprint': contentFingerprint,
        'headSnapshot': headSnapshot,
        'updatedAtUtc': updatedAtUtc,
        'snapshotSizeBytes': snapshotSizeBytes,
        'hasRestoreWrap': hasRestoreWrap,
        if (wrapKind != null && wrapKind!.isNotEmpty) 'wrapKind': wrapKind,
        'snapshots': snapshots.map((e) => e.toJson()).toList(),
      };

  List<int> toUtf8Bytes() => utf8.encode(jsonEncode(toJson()));

  static VaultPackMeta? fromJsonBytes(List<int> raw) {
    try {
      final dynamic decoded = jsonDecode(utf8.decode(raw));
      if (decoded is! Map) return null;
      return fromJson(
        Map<String, Object?>.from(
          decoded.map((k, v) => MapEntry('$k', v)),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static VaultPackMeta? fromJson(Map<String, Object?> m) {
    final fvRaw = m['formatVersion'];
    final fv = fvRaw is int
        ? fvRaw
        : fvRaw is num
            ? fvRaw.toInt()
            : int.tryParse('$fvRaw');
    if (fv == null || fv != currentFormatVersion) return null;
    final fp = m['contentFingerprint']?.toString().trim().toLowerCase() ?? '';
    final head = m['headSnapshot']?.toString().trim() ?? '';
    final updated = m['updatedAtUtc']?.toString().trim() ?? '';
    if (fp.isEmpty || head.isEmpty || updated.isEmpty) return null;
    final sizeRaw = m['snapshotSizeBytes'];
    final size = sizeRaw is int
        ? sizeRaw
        : sizeRaw is num
            ? sizeRaw.toInt()
            : int.tryParse('$sizeRaw') ?? 0;
    final wrapKind = m['wrapKind']?.toString().trim();
    final snaps = <VaultPackSnapshotRef>[];
    final rawSnaps = m['snapshots'];
    if (rawSnaps is List) {
      for (final e in rawSnaps) {
        if (e is! Map) continue;
        final ref = VaultPackSnapshotRef.fromJson(
          Map<String, Object?>.from(e.map((k, v) => MapEntry('$k', v))),
        );
        if (ref != null) snaps.add(ref);
      }
    }
    return VaultPackMeta(
      formatVersion: fv,
      contentFingerprint: fp,
      headSnapshot: head,
      updatedAtUtc: updated,
      snapshotSizeBytes: size < 0 ? 0 : size,
      hasRestoreWrap: m['hasRestoreWrap'] == true,
      wrapKind: (wrapKind != null && wrapKind.isNotEmpty) ? wrapKind : null,
      snapshots: snaps,
    );
  }
}

class VaultPackSnapshotRef {
  const VaultPackSnapshotRef({
    required this.path,
    required this.createdAtUtc,
    required this.contentFingerprint,
    this.sizeBytes = 0,
  });

  final String path;
  final String createdAtUtc;
  final String contentFingerprint;
  final int sizeBytes;

  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'createdAtUtc': createdAtUtc,
        'contentFingerprint': contentFingerprint,
        'sizeBytes': sizeBytes,
      };

  static VaultPackSnapshotRef? fromJson(Map<String, Object?> m) {
    final path = m['path']?.toString().trim() ?? '';
    final created = m['createdAtUtc']?.toString().trim() ?? '';
    final fp = m['contentFingerprint']?.toString().trim().toLowerCase() ?? '';
    if (path.isEmpty || created.isEmpty || fp.isEmpty) return null;
    final sizeRaw = m['sizeBytes'];
    final size = sizeRaw is int
        ? sizeRaw
        : sizeRaw is num
            ? sizeRaw.toInt()
            : int.tryParse('$sizeRaw') ?? 0;
    return VaultPackSnapshotRef(
      path: path,
      createdAtUtc: created,
      contentFingerprint: fp,
      sizeBytes: size < 0 ? 0 : size,
    );
  }
}
