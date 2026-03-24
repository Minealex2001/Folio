import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class VaultPaths {
  VaultPaths._();

  /// Carpeta legacy (una sola); se migra a [vaultsContainerDirName].
  static const String legacyVaultDirName = 'folio_vault';

  /// Contenedor de todos los cofres: `<support>/folio_vaults/<vaultId>/`.
  static const String vaultsContainerDirName = 'folio_vaults';

  static const String attachmentsDirName = 'attachments';
  static const String wrappedDekFile = 'vault.keys';
  static const String cipherPayloadFile = 'vault.bin';
  static const String rpStateFile = 'webauthn_rp.json';

  static const _uuid = Uuid();

  static String? _activeVaultId;

  static String? get activeVaultId => _activeVaultId;

  static void setActiveVaultId(String? id) {
    _activeVaultId = id;
  }

  static void clearActiveVaultId() {
    _activeVaultId = null;
  }

  static Future<Directory> vaultsRootDirectory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, vaultsContainerDirName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Directorio de un cofre por id (crea la carpeta si no existe).
  static Future<Directory> vaultDirectoryForId(String vaultId) async {
    final vRoot = await vaultsRootDirectory();
    final dir = Directory(p.join(vRoot.path, vaultId));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Cofre activo; requiere [setActiveVaultId] previo.
  static Future<Directory> vaultDirectory() async {
    final id = _activeVaultId;
    if (id == null || id.isEmpty) {
      throw StateError('No hay cofre activo');
    }
    return vaultDirectoryForId(id);
  }

  static Future<Directory> attachmentsDirectory() async {
    final v = await vaultDirectory();
    final dir = Directory(p.join(v.path, attachmentsDirName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ruta relativa al directorio del cofre, p. ej. `attachments/uuid.png`.
  static Future<String> importAttachmentFile(
    File source, {
    bool preserveExtension = false,
    bool preserveFileName = false,
  }) async {
    await attachmentsDirectory();
    final vault = await vaultDirectory();
    final ext = p.extension(source.path).toLowerCase();
    final safeExt = preserveExtension
        ? _safeAttachmentExtension(ext)
        : _safeImageExtension(ext);
    final name = preserveFileName
        ? await _buildPreservedFileName(vault, source.path, safeExt)
        : '${_uuid.v4()}$safeExt';
    final relative = p.join(attachmentsDirName, name);
    final dest = File(p.join(vault.path, relative));
    await source.copy(dest.path);
    return relative.replaceAll(r'\', '/');
  }

  static Future<String> _buildPreservedFileName(
    Directory vault,
    String sourcePath,
    String safeExt,
  ) async {
    final originalBase = p.basenameWithoutExtension(sourcePath);
    final cleanBase = _sanitizeBaseName(originalBase);
    final direct = '$cleanBase$safeExt';
    final directPath = p.join(vault.path, attachmentsDirName, direct);
    if (!File(directPath).existsSync()) return direct;
    final suffix = _uuid.v4().split('-').first;
    return '${cleanBase}_$suffix$safeExt';
  }

  static String _sanitizeBaseName(String base) {
    final cleaned = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'archivo';
    if (cleaned.length <= 64) return cleaned;
    return cleaned.substring(0, 64).trim();
  }

  static String _safeImageExtension(String ext) {
    const ok = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};
    return ok.contains(ext) ? ext : '.bin';
  }

  static String _safeAttachmentExtension(String ext) {
    if (ext.isEmpty) return '.bin';
    final clean = ext.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '');
    if (clean.length < 2 || clean.length > 12 || !clean.startsWith('.')) {
      return '.bin';
    }
    return clean;
  }

  /// [relativePath] como guardada en el bloque (`attachments/...`).
  static Future<void> deleteAttachmentIfExists(String relativePath) async {
    final t = relativePath.trim();
    if (t.isEmpty) return;
    if (!t.startsWith('$attachmentsDirName/')) return;
    final vault = await vaultDirectory();
    final full = p.join(vault.path, t);
    final f = File(full);
    if (f.existsSync()) {
      await f.delete();
    }
  }

  static Future<File> wrappedDekPath() async {
    final d = await vaultDirectory();
    return File(p.join(d.path, wrappedDekFile));
  }

  static Future<File> cipherPayloadPath() async {
    final d = await vaultDirectory();
    return File(p.join(d.path, cipherPayloadFile));
  }

  static Future<File> rpStatePath() async {
    final d = await vaultDirectory();
    return File(p.join(d.path, rpStateFile));
  }

  static Future<bool> vaultExists() async {
    final id = _activeVaultId;
    if (id == null || id.isEmpty) return false;
    final f = File(
      p.join((await vaultDirectoryForId(id)).path, wrappedDekFile),
    );
    return f.existsSync();
  }

  static Future<bool> vaultExistsForId(String vaultId) async {
    final f = File(
      p.join((await vaultDirectoryForId(vaultId)).path, wrappedDekFile),
    );
    return f.existsSync();
  }

  /// Borra el material cifrado del cofre activo (no toca otras prefs globales antiguas).
  static Future<void> deleteWrappedKeyAndPayload() async {
    final w = await wrappedDekPath();
    if (w.existsSync()) {
      await w.delete();
    }
    final c = await cipherPayloadPath();
    if (c.existsSync()) {
      await c.delete();
    }
    await clearAttachmentsDirectory();
  }

  static Future<void> clearAttachmentsDirectory() async {
    try {
      final v = await vaultDirectory();
      final dir = Directory(p.join(v.path, attachmentsDirName));
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Elimina por completo la carpeta `folio_vaults/<vaultId>/`.
  static Future<void> deleteVaultDirectory(String vaultId) async {
    try {
      final vRoot = await vaultsRootDirectory();
      final dir = Directory(p.join(vRoot.path, vaultId));
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
