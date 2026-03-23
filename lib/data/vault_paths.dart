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
  static Future<String> importAttachmentFile(File source) async {
    await attachmentsDirectory();
    final vault = await vaultDirectory();
    final ext = p.extension(source.path).toLowerCase();
    const ok = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};
    final safeExt = ok.contains(ext) ? ext : '.bin';
    final name = '${_uuid.v4()}$safeExt';
    final relative = p.join(attachmentsDirName, name);
    final dest = File(p.join(vault.path, relative));
    await source.copy(dest.path);
    return relative.replaceAll(r'\', '/');
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
