import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'storage/vault_storage.dart';

class VaultPaths {
  VaultPaths._();

  /// Carpeta legacy (una sola); se migra a [vaultsContainerDirName].
  static const String legacyVaultDirName = 'folio_vault';

  /// Contenedor de todas las libretas: `<support>/folio_vaults/<vaultId>/`.
  static const String vaultsContainerDirName = 'folio_vaults';

  static const String attachmentsDirName = 'attachments';
  static const String wrappedDekFile = 'vault.keys';
  static const String cipherPayloadFile = 'vault.bin';
  static const String vaultModeFile = 'vault.mode';
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

  // ── Byte-level vault file accessors (cross-platform) ──────────────────

  static String _assertVaultId() {
    final id = _activeVaultId;
    if (id == null || id.isEmpty) throw StateError('No hay libreta activa');
    return id;
  }

  static Future<Uint8List?> readWrappedDek() =>
      VaultStorage.instance.readVaultFile(_assertVaultId(), wrappedDekFile);

  static Future<void> writeWrappedDek(Uint8List data) =>
      VaultStorage.instance.writeVaultFile(_assertVaultId(), wrappedDekFile, data);

  static Future<void> deleteWrappedDek() =>
      VaultStorage.instance.deleteVaultFile(_assertVaultId(), wrappedDekFile);

  static Future<bool> wrappedDekExists() =>
      VaultStorage.instance.vaultFileExists(_assertVaultId(), wrappedDekFile);

  static Future<Uint8List?> readCipherPayload() =>
      VaultStorage.instance.readVaultFile(_assertVaultId(), cipherPayloadFile);

  static Future<void> writeCipherPayload(Uint8List data) =>
      VaultStorage.instance.writeVaultFile(_assertVaultId(), cipherPayloadFile, data);

  static Future<bool> cipherPayloadExists() =>
      VaultStorage.instance.vaultFileExists(_assertVaultId(), cipherPayloadFile);

  static Future<String?> readVaultMode() async {
    final bytes =
        await VaultStorage.instance.readVaultFile(_assertVaultId(), vaultModeFile);
    if (bytes == null) return null;
    return String.fromCharCodes(bytes).trim();
  }

  static Future<void> writeVaultMode(String mode) =>
      VaultStorage.instance.writeVaultFile(
        _assertVaultId(),
        vaultModeFile,
        Uint8List.fromList(mode.codeUnits),
      );

  static Future<String?> readRpState() async {
    final bytes =
        await VaultStorage.instance.readVaultFile(_assertVaultId(), rpStateFile);
    if (bytes == null) return null;
    return String.fromCharCodes(bytes);
  }

  static Future<void> writeRpState(String json) =>
      VaultStorage.instance.writeVaultFile(
        _assertVaultId(),
        rpStateFile,
        Uint8List.fromList(json.codeUnits),
      );

  static Future<bool> rpStateExists() =>
      VaultStorage.instance.vaultFileExists(_assertVaultId(), rpStateFile);

  // ── Vault lifecycle (cross-platform) ──────────────────────────────────

  static Future<bool> vaultExists() async {
    final id = _activeVaultId;
    if (id == null || id.isEmpty) return false;
    return VaultStorage.instance.vaultExists(id);
  }

  static Future<bool> vaultExistsForId(String vaultId) =>
      VaultStorage.instance.vaultExists(vaultId);

  /// Ensures storage exists for [vaultId].
  /// On native: also creates the filesystem directory.
  /// On web: no-op (IndexedDB is always available).
  static Future<void> initVaultStorage(String vaultId) =>
      VaultStorage.instance.initVault(vaultId);

  static Future<void> deleteWrappedKeyAndPayload() async {
    final id = _activeVaultId;
    if (id == null || id.isEmpty) return;
    await VaultStorage.instance.deleteVaultFile(id, wrappedDekFile);
    await VaultStorage.instance.deleteVaultFile(id, cipherPayloadFile);
    await VaultStorage.instance.deleteVaultFile(id, vaultModeFile);
    await VaultStorage.instance.clearAttachments(id);
  }

  static Future<void> clearAttachmentsDirectory() async {
    final id = _activeVaultId;
    if (id == null || id.isEmpty) return;
    await VaultStorage.instance.clearAttachments(id);
  }

  static Future<void> deleteVaultDirectory(String vaultId) =>
      VaultStorage.instance.deleteVault(vaultId);

  // ── Attachment operations (cross-platform) ────────────────────────────

  /// Imports raw bytes as a vault attachment. Returns a relative path
  /// like `attachments/uuid.png`.
  static Future<String> importAttachmentBytes(
    Uint8List bytes,
    String ext, {
    bool preserveExtension = false,
    String? preferredName,
  }) {
    final id = _assertVaultId();
    return VaultStorage.instance.importAttachmentBytes(
      id,
      bytes,
      ext,
      preferredName: preferredName,
    );
  }

  /// Reads attachment bytes for [relativePath] (e.g. `attachments/uuid.png`).
  static Future<Uint8List?> readAttachmentBytes(String relativePath) {
    final id = _activeVaultId;
    if (id == null || id.isEmpty) return Future.value(null);
    return VaultStorage.instance.readAttachment(id, relativePath);
  }

  /// [relativePath] como guardada en el bloque (`attachments/...`).
  static Future<void> deleteAttachmentIfExists(String relativePath) async {
    final t = relativePath.trim();
    if (t.isEmpty) return;
    if (!t.startsWith('$attachmentsDirName/')) return;
    final id = _activeVaultId;
    if (id == null || id.isEmpty) return;
    await VaultStorage.instance.deleteAttachment(id, t);
  }

  // ── Native-only: File-system operations ───────────────────────────────
  // These throw at runtime on web. Callers must guard with `if (!kIsWeb)`.

  static Future<Directory> vaultsRootDirectory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, vaultsContainerDirName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ensures the native directory exists and returns it.
  /// Also calls [initVaultStorage] so the VaultStorage backend is aware.
  static Future<Directory> vaultDirectoryForId(String vaultId) async {
    await VaultStorage.instance.initVault(vaultId);
    final vRoot = await vaultsRootDirectory();
    final dir = Directory(p.join(vRoot.path, vaultId));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Libreta activa; requiere [setActiveVaultId] previo.
  static Future<Directory> vaultDirectory() async {
    final id = _activeVaultId;
    if (id == null || id.isEmpty) {
      throw StateError('No hay libreta activa');
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

  /// Imports a native [File] as a vault attachment. Native-only.
  /// On web, use [importAttachmentBytes] instead.
  static Future<String> importAttachmentFile(
    File source, {
    bool preserveExtension = false,
    bool preserveFileName = false,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('importAttachmentFile not supported on web. Use importAttachmentBytes.');
    }
    final id = _assertVaultId();
    return VaultStorage.instance.importAttachmentFromFile(
      id,
      source,
      preserveExtension: preserveExtension,
      preserveFileName: preserveFileName,
    );
  }

  /// Suma los tamaños de todos los archivos bajo [root] (recursivo).
  static Future<int> directoryTotalFileBytes(Directory root) async {
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  // ── Native-only: legacy File-path helpers (native callers only) ───────
  // These exist so native-only code (vault_backup, cloud_pack_sync) can get
  // a File reference. They must not be called on web; each function that uses
  // them already has a kIsWeb guard at its entry point.

  static Future<File> wrappedDekPath() async {
    final dir = await vaultDirectory();
    return File(p.join(dir.path, wrappedDekFile));
  }

  static Future<File> cipherPayloadPath() async {
    final dir = await vaultDirectory();
    return File(p.join(dir.path, cipherPayloadFile));
  }

  static Future<File> vaultModePath() async {
    final dir = await vaultDirectory();
    return File(p.join(dir.path, vaultModeFile));
  }
}