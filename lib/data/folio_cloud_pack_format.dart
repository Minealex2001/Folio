import 'dart:convert';

import '../services/folio_cloud/folio_cloud_blob_codec.dart';

/// Formato de copia incremental en la nube (cloud-pack). El JSON en claro solo
/// existe en memoria; lo que sube a Storage es el ciphertext (AES-GCM) del snapshot.
///
/// - v1: un blob por rol lógico (sin troceo ni envelope de compresión).
/// - v2: mismos roles; un rol lógico puede ocupar varios items (`chunkIndex`/
///   `chunkCount`) y el plaintext cifrado lleva envelope gzip/raw.
const int kFolioCloudPackFormatVersion = 2;

/// Versiones de manifiesto que este cliente acepta al leer.
const Set<int> kFolioCloudPackReadableFormatVersions = {1, 2};

/// Rol de cada blob referenciado por un snapshot.
enum FolioCloudPackBlobRole {
  backupManifest,
  vaultKeys,
  vaultBin,
  vaultMode,
  attachment,
}

String folioCloudPackRoleWire(FolioCloudPackBlobRole r) {
  switch (r) {
    case FolioCloudPackBlobRole.backupManifest:
      return 'manifest';
    case FolioCloudPackBlobRole.vaultKeys:
      return 'vault_keys';
    case FolioCloudPackBlobRole.vaultBin:
      return 'vault_bin';
    case FolioCloudPackBlobRole.vaultMode:
      return 'vault_mode';
    case FolioCloudPackBlobRole.attachment:
      return 'attachment';
  }
}

FolioCloudPackBlobRole? folioCloudPackRoleParse(String w) {
  switch (w) {
    case 'manifest':
      return FolioCloudPackBlobRole.backupManifest;
    case 'vault_keys':
      return FolioCloudPackBlobRole.vaultKeys;
    case 'vault_bin':
      return FolioCloudPackBlobRole.vaultBin;
    case 'vault_mode':
      return FolioCloudPackBlobRole.vaultMode;
    case 'attachment':
      return FolioCloudPackBlobRole.attachment;
    default:
      return null;
  }
}

/// Entrada en el manifiesto del snapshot (referencia a un blob cifrado en Storage).
class FolioCloudPackSnapshotItem {
  const FolioCloudPackSnapshotItem({
    required this.role,
    required this.blobId,
    this.relativePath,
    this.chunkIndex = 0,
    this.chunkCount = 1,
    this.compression = FolioCloudBlobCompression.none,
  });

  final FolioCloudPackBlobRole role;
  final String blobId;

  /// Solo [FolioCloudPackBlobRole.attachment]: ruta posix bajo la libreta, p. ej. `attachments/x.png`.
  final String? relativePath;

  /// Índice 0-based de este trozo dentro del rol lógico.
  final int chunkIndex;

  /// Número total de trozos del rol lógico (≥ 1).
  final int chunkCount;

  /// Compresión del stream envelope (informativo; el flag va en el plaintext).
  final FolioCloudBlobCompression compression;

  bool get isChunked => chunkCount > 1;

  Map<String, Object?> toJson() => <String, Object?>{
        'role': folioCloudPackRoleWire(role),
        'blobId': blobId,
        if (relativePath != null && relativePath!.isNotEmpty)
          'path': relativePath,
        if (chunkCount > 1 || chunkIndex != 0) ...<String, Object?>{
          'chunkIndex': chunkIndex,
          'chunkCount': chunkCount,
        },
        if (compression != FolioCloudBlobCompression.none)
          'compression': folioCloudBlobCompressionWire(compression),
      };

  static FolioCloudPackSnapshotItem? fromJson(Map<String, Object?> m) {
    final roleRaw = m['role']?.toString() ?? '';
    final role = folioCloudPackRoleParse(roleRaw);
    if (role == null) return null;
    final blobId = m['blobId']?.toString().trim().toLowerCase() ?? '';
    if (!_isHex64(blobId)) return null;
    final path = m['path']?.toString();
    if (role == FolioCloudPackBlobRole.attachment &&
        (path == null || path.isEmpty)) {
      return null;
    }
    if (role != FolioCloudPackBlobRole.attachment &&
        path != null &&
        path.isNotEmpty) {
      return null;
    }

    final chunkIndex = _parseNonNegInt(m['chunkIndex']) ?? 0;
    final chunkCount = _parseNonNegInt(m['chunkCount']) ?? 1;
    if (chunkCount < 1 || chunkIndex < 0 || chunkIndex >= chunkCount) {
      return null;
    }
    final compression =
        folioCloudBlobCompressionParse(m['compression']?.toString()) ??
            FolioCloudBlobCompression.none;

    return FolioCloudPackSnapshotItem(
      role: role,
      blobId: blobId,
      relativePath: role == FolioCloudPackBlobRole.attachment ? path : null,
      chunkIndex: chunkIndex,
      chunkCount: chunkCount,
      compression: compression,
    );
  }
}

/// Manifiesto en claro antes de cifrar el snapshot.
class FolioCloudPackSnapshotManifest {
  const FolioCloudPackSnapshotManifest({
    required this.formatVersion,
    required this.createdAtUtc,
    required this.items,
    this.contentFingerprint,
  });

  final int formatVersion;
  final String createdAtUtc;
  final List<FolioCloudPackSnapshotItem> items;

  /// SHA-256 hex del estado local usado para omitir subidas idénticas (opcional).
  final String? contentFingerprint;

  Map<String, Object?> toJson() => <String, Object?>{
        'formatVersion': formatVersion,
        'createdAtUtc': createdAtUtc,
        'items': items.map((e) => e.toJson()).toList(),
        if (contentFingerprint != null && contentFingerprint!.isNotEmpty)
          'contentFingerprint': contentFingerprint,
      };

  static FolioCloudPackSnapshotManifest? fromJsonBytes(List<int> raw) {
    try {
      final dynamic decoded = jsonDecode(utf8.decode(raw));
      if (decoded is! Map) return null;
      final m = Map<String, Object?>.from(
        decoded.map((k, v) => MapEntry('$k', v)),
      );
      final fv = m['formatVersion'];
      final v = fv is int
          ? fv
          : fv is num
              ? fv.toInt()
              : int.tryParse('$fv');
      if (v == null || !kFolioCloudPackReadableFormatVersions.contains(v)) {
        return null;
      }
      final created = m['createdAtUtc']?.toString() ?? '';
      if (created.isEmpty) return null;
      final rawItems = m['items'];
      if (rawItems is! List) return null;
      final items = <FolioCloudPackSnapshotItem>[];
      for (final e in rawItems) {
        if (e is! Map) continue;
        final it = FolioCloudPackSnapshotItem.fromJson(
          Map<String, Object?>.from(e.map((k, v) => MapEntry('$k', v))),
        );
        if (it == null) return null;
        items.add(it);
      }
      if (!_itemsWellFormed(items, formatVersion: v)) return null;
      final fp = m['contentFingerprint']?.toString().trim().toLowerCase();
      return FolioCloudPackSnapshotManifest(
        formatVersion: v,
        createdAtUtc: created,
        items: items,
        contentFingerprint: (fp != null && fp.isNotEmpty) ? fp : null,
      );
    } catch (_) {
      return null;
    }
  }

  List<int> toUtf8Bytes() => utf8.encode(jsonEncode(toJson()));
}

bool _isHex64(String s) =>
    s.length == 64 && RegExp(r'^[0-9a-f]+$').hasMatch(s);

int? _parseNonNegInt(Object? v) {
  if (v is int) return v >= 0 ? v : null;
  if (v is num) {
    final i = v.toInt();
    return i >= 0 ? i : null;
  }
  return int.tryParse('$v');
}

bool _itemsWellFormed(
  List<FolioCloudPackSnapshotItem> items, {
  required int formatVersion,
}) {
  var hasManifest = false;
  var hasBin = false;
  final paths = <String>{};
  // Agrupar por (role, path?) y validar chunks contiguos 0..N-1.
  final groups = <String, List<FolioCloudPackSnapshotItem>>{};
  for (final it in items) {
    final key = it.role == FolioCloudPackBlobRole.attachment
        ? 'att:${it.relativePath}'
        : 'role:${folioCloudPackRoleWire(it.role)}';
    groups.putIfAbsent(key, () => []).add(it);
  }

  for (final entry in groups.entries) {
    final group = entry.value;
    final count = group.first.chunkCount;
    if (group.any((g) => g.chunkCount != count)) return false;
    if (group.length != count) return false;
    final indexes = group.map((g) => g.chunkIndex).toSet();
    if (indexes.length != count) return false;
    for (var i = 0; i < count; i++) {
      if (!indexes.contains(i)) return false;
    }

    final role = group.first.role;
    switch (role) {
      case FolioCloudPackBlobRole.backupManifest:
        if (hasManifest) return false;
        hasManifest = true;
      case FolioCloudPackBlobRole.vaultBin:
        if (hasBin) return false;
        hasBin = true;
      case FolioCloudPackBlobRole.vaultKeys:
      case FolioCloudPackBlobRole.vaultMode:
        break;
      case FolioCloudPackBlobRole.attachment:
        final p = group.first.relativePath!;
        if (paths.contains(p)) return false;
        paths.add(p);
    }

    // v1 no debería declarar trozos; si los hay, exigir format ≥ 2.
    if (count > 1 && formatVersion < 2) return false;
  }
  return hasManifest && hasBin;
}
