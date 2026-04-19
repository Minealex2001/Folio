import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Native (dart:io) implementation of VaultStorage.
class VaultStorage {
  VaultStorage._();
  static final VaultStorage instance = VaultStorage._();

  static const String _container = 'folio_vaults';
  static const String _attachmentsDir = 'attachments';
  static const _uuid = Uuid();

  // ── Internal helpers ─────────────────────────────────────────────────

  Future<String> _vaultDirPath(String vaultId) async {
    final root = await getApplicationSupportDirectory();
    return p.join(root.path, _container, vaultId);
  }

  Future<File> _file(String vaultId, String filename) async {
    final dir = await _vaultDirPath(vaultId);
    final f = File(p.join(dir, filename));
    await f.parent.create(recursive: true);
    return f;
  }

  // ── Vault file operations ─────────────────────────────────────────────

  Future<Uint8List?> readVaultFile(String vaultId, String filename) async {
    final dir = await _vaultDirPath(vaultId);
    final f = File(p.join(dir, filename));
    if (!f.existsSync()) return null;
    return f.readAsBytes();
  }

  Future<void> writeVaultFile(
    String vaultId,
    String filename,
    Uint8List data,
  ) async {
    final f = await _file(vaultId, filename);
    await f.writeAsBytes(data, flush: true);
  }

  Future<bool> vaultFileExists(String vaultId, String filename) async {
    final dir = await _vaultDirPath(vaultId);
    return File(p.join(dir, filename)).existsSync();
  }

  Future<void> deleteVaultFile(String vaultId, String filename) async {
    final dir = await _vaultDirPath(vaultId);
    final f = File(p.join(dir, filename));
    if (f.existsSync()) await f.delete();
  }

  Future<int> vaultFileSize(String vaultId, String filename) async {
    final dir = await _vaultDirPath(vaultId);
    final f = File(p.join(dir, filename));
    if (!f.existsSync()) return 0;
    return f.length();
  }

  // ── Vault lifecycle ────────────────────────────────────────────────────

  Future<bool> vaultExists(String vaultId) async {
    final dir = await _vaultDirPath(vaultId);
    return File(p.join(dir, 'vault.keys')).existsSync() ||
        File(p.join(dir, 'vault.bin')).existsSync();
  }

  /// Ensures the vault storage namespace exists (creates directory on native).
  Future<void> initVault(String vaultId) async {
    final dir = await _vaultDirPath(vaultId);
    await Directory(dir).create(recursive: true);
  }

  Future<void> deleteVault(String vaultId) async {
    final dir = await _vaultDirPath(vaultId);
    final d = Directory(dir);
    if (d.existsSync()) await d.delete(recursive: true);
  }

  Future<int> vaultTotalBytes(String vaultId) async {
    final dir = await _vaultDirPath(vaultId);
    final d = Directory(dir);
    if (!d.existsSync()) return 0;
    var total = 0;
    await for (final entity in d.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  // ── Attachment operations ─────────────────────────────────────────────

  Future<String> importAttachmentBytes(
    String vaultId,
    Uint8List bytes,
    String ext, {
    String? preferredName,
  }) async {
    final dir = await _vaultDirPath(vaultId);
    final attDir = Directory(p.join(dir, _attachmentsDir));
    await attDir.create(recursive: true);
    final safeExt = _safeAttachmentExt(ext);
    final name = preferredName != null
        ? _buildPreservedName(attDir.path, preferredName, safeExt)
        : '${_uuid.v4()}$safeExt';
    final relative = '$_attachmentsDir/$name';
    await File(p.join(dir, relative)).writeAsBytes(bytes);
    return relative;
  }

  Future<String> importAttachmentFromFile(
    String vaultId,
    File source, {
    bool preserveExtension = false,
    bool preserveFileName = false,
  }) async {
    final dir = await _vaultDirPath(vaultId);
    final attDir = Directory(p.join(dir, _attachmentsDir));
    await attDir.create(recursive: true);
    final ext = p.extension(source.path).toLowerCase();
    final safeExt =
        preserveExtension ? _safeAttachmentExt(ext) : _safeImageExt(ext);
    String name;
    if (preserveFileName) {
      name = _buildPreservedName(
        attDir.path,
        p.basenameWithoutExtension(source.path),
        safeExt,
      );
    } else {
      name = '${_uuid.v4()}$safeExt';
    }
    final relative = '$_attachmentsDir/$name';
    await source.copy(p.join(dir, relative));
    return relative;
  }

  Future<Uint8List?> readAttachment(
    String vaultId,
    String relativePath,
  ) async {
    if (!relativePath.startsWith('$_attachmentsDir/')) return null;
    final dir = await _vaultDirPath(vaultId);
    final f = File(p.join(dir, relativePath));
    if (!f.existsSync()) return null;
    return f.readAsBytes();
  }

  Future<void> deleteAttachment(String vaultId, String relativePath) async {
    if (!relativePath.startsWith('$_attachmentsDir/')) return;
    final dir = await _vaultDirPath(vaultId);
    final f = File(p.join(dir, relativePath));
    if (f.existsSync()) await f.delete();
  }

  Future<void> clearAttachments(String vaultId) async {
    final dir = await _vaultDirPath(vaultId);
    final d = Directory(p.join(dir, _attachmentsDir));
    if (d.existsSync()) await d.delete(recursive: true);
  }

  Future<List<String>> listAttachmentPaths(String vaultId) async {
    final dir = await _vaultDirPath(vaultId);
    final d = Directory(p.join(dir, _attachmentsDir));
    if (!d.existsSync()) return const [];
    final result = <String>[];
    await for (final f in d.list(followLinks: false)) {
      if (f is File) {
        result.add('$_attachmentsDir/${p.basename(f.path)}');
      }
    }
    return result;
  }

  /// Returns the native vault Directory (null on web – this impl never returns null).
  Future<Directory?> getNativeVaultDirectory(String vaultId) async {
    final dir = await _vaultDirPath(vaultId);
    await Directory(dir).create(recursive: true);
    return Directory(dir);
  }

  // ── Private helpers ────────────────────────────────────────────────────

  static String _buildPreservedName(
    String attDirPath,
    String baseName,
    String ext,
  ) {
    final clean = _sanitizeBase(baseName);
    final direct = '$clean$ext';
    if (!File(p.join(attDirPath, direct)).existsSync()) return direct;
    final suffix = const Uuid().v4().split('-').first;
    return '${clean}_$suffix$ext';
  }

  static String _sanitizeBase(String base) {
    final cleaned = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'archivo';
    return cleaned.length <= 64 ? cleaned : cleaned.substring(0, 64).trim();
  }

  static String _safeImageExt(String ext) {
    const ok = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};
    return ok.contains(ext) ? ext : '.bin';
  }

  static String _safeAttachmentExt(String ext) {
    if (ext.isEmpty) return '.bin';
    final clean = ext.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '');
    if (clean.length < 2 || clean.length > 12 || !clean.startsWith('.')) {
      return '.bin';
    }
    return clean;
  }
}
