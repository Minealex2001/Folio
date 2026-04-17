import 'dart:convert';

/// Formato de copia incremental en la nube (cloud-pack). El JSON en claro solo
/// existe en memoria; lo que sube a Storage es el ciphertext (AES-GCM) del snapshot.
const int kFolioCloudPackFormatVersion = 1;

/// Rol de cada blob referenciado por un snapshot.
enum FolioCloudPackBlobRole {
  backupManifest,
  vaultKeys,
  vaultBin,
  vaultMode,
  attachment,
}

String _roleWire(FolioCloudPackBlobRole r) {
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

FolioCloudPackBlobRole? _roleParse(String w) {
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
  });

  final FolioCloudPackBlobRole role;
  final String blobId;

  /// Solo [FolioCloudPackBlobRole.attachment]: ruta posix bajo la libreta, p. ej. `attachments/x.png`.
  final String? relativePath;

  Map<String, Object?> toJson() => <String, Object?>{
        'role': _roleWire(role),
        'blobId': blobId,
        if (relativePath != null && relativePath!.isNotEmpty)
          'path': relativePath,
      };

  static FolioCloudPackSnapshotItem? fromJson(Map<String, Object?> m) {
    final roleRaw = m['role']?.toString() ?? '';
    final role = _roleParse(roleRaw);
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
    return FolioCloudPackSnapshotItem(
      role: role,
      blobId: blobId,
      relativePath: role == FolioCloudPackBlobRole.attachment ? path : null,
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
      if (v == null || v != kFolioCloudPackFormatVersion) return null;
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
      if (!_itemsWellFormed(items)) return null;
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

bool _itemsWellFormed(List<FolioCloudPackSnapshotItem> items) {
  var hasManifest = false;
  var hasBin = false;
  final paths = <String>{};
  for (final it in items) {
    switch (it.role) {
      case FolioCloudPackBlobRole.backupManifest:
        if (hasManifest) return false;
        hasManifest = true;
      case FolioCloudPackBlobRole.vaultBin:
        if (hasBin) return false;
        hasBin = true;
      case FolioCloudPackBlobRole.vaultKeys:
      case FolioCloudPackBlobRole.vaultMode:
      case FolioCloudPackBlobRole.attachment:
        break;
    }
    if (it.role == FolioCloudPackBlobRole.attachment) {
      final p = it.relativePath!;
      if (paths.contains(p)) return false;
      paths.add(p);
    }
  }
  return hasManifest && hasBin;
}
