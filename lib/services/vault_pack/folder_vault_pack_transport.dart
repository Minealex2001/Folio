import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/vault_backup.dart';
import '../backup_destinations/smb_network_auth.dart';
import 'vault_pack_meta.dart';
import 'vault_pack_paths.dart';
import 'vault_pack_transport.dart';

/// Pack incremental en carpeta local / UNC.
class FolderVaultPackTransport implements VaultPackTransport {
  FolderVaultPackTransport({
    required this.rootDirectoryPath,
    required this.vaultId,
    this.folderRequiresAuth = false,
    this.username = '',
    this.password = '',
    this.domain = '',
    SmbNetworkAuth? smbAuth,
  }) : _smbAuth = smbAuth ?? SmbNetworkAuth();

  final String rootDirectoryPath;
  final String vaultId;
  final bool folderRequiresAuth;
  final String username;
  final String password;
  final String domain;
  final SmbNetworkAuth _smbAuth;

  @override
  String get label => packRootPath;

  String get packRootPath =>
      p.join(rootDirectoryPath.trim(), kVaultPackRootDirName, vaultId.trim());

  Directory get _root => Directory(packRootPath);

  Future<T> _withAuth<T>(Future<T> Function() action) async {
    late T result;
    await _smbAuth.withConnection(
      path: rootDirectoryPath,
      folderRequiresAuth: folderRequiresAuth,
      username: username,
      password: password,
      domain: domain,
      action: () async {
        result = await action();
      },
    );
    return result;
  }

  Future<void> _ensurePackDirs() async {
    final root = _root;
    if (!root.existsSync()) {
      await root.create(recursive: true);
    }
    final blobs = Directory(p.join(root.path, kVaultPackBlobsDirName));
    if (!blobs.existsSync()) await blobs.create(recursive: true);
    final snaps = Directory(p.join(root.path, kVaultPackSnapshotsDirName));
    if (!snaps.existsSync()) await snaps.create(recursive: true);
  }

  File _blobFile(String blobId) =>
      File(p.join(packRootPath, kVaultPackBlobsDirName, blobId));

  File _relFile(String relativePosix) {
    final parts = relativePosix.replaceAll(r'\', '/').split('/');
    return File(p.joinAll([packRootPath, ...parts]));
  }

  @override
  Future<VaultPackMeta?> readMeta() async {
    return _withAuth(() async {
      final f = File(p.join(packRootPath, kVaultPackMetaFileName));
      if (!f.existsSync()) return null;
      return VaultPackMeta.fromJsonBytes(await f.readAsBytes());
    });
  }

  @override
  Future<void> writeMeta(VaultPackMeta meta) async {
    await _withAuth(() async {
      await _ensurePackDirs();
      final f = File(p.join(packRootPath, kVaultPackMetaFileName));
      await f.writeAsBytes(meta.toUtf8Bytes(), flush: true);
    });
  }

  @override
  Future<bool> blobExists(String blobId) async {
    return _withAuth(() async {
      return _blobFile(blobId).existsSync();
    });
  }

  @override
  Future<void> putBlob(String blobId, Uint8List bytes) async {
    await _withAuth(() async {
      await _ensurePackDirs();
      final f = _blobFile(blobId);
      if (f.existsSync()) return;
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      if (f.existsSync()) {
        await tmp.delete();
        return;
      }
      await tmp.rename(f.path);
    });
  }

  @override
  Future<Uint8List?> getBlob(String blobId) async {
    return _withAuth(() async {
      final f = _blobFile(blobId);
      if (!f.existsSync()) return null;
      return Uint8List.fromList(await f.readAsBytes());
    });
  }

  @override
  Future<void> deleteBlob(String blobId) async {
    await _withAuth(() async {
      final f = _blobFile(blobId);
      if (f.existsSync()) await f.delete();
    });
  }

  @override
  Future<void> putSnapshot(String relativePath, Uint8List bytes) async {
    await _withAuth(() async {
      await _ensurePackDirs();
      final f = _relFile(relativePath);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes, flush: true);
    });
  }

  @override
  Future<Uint8List?> getSnapshot(String relativePath) async {
    return _withAuth(() async {
      final f = _relFile(relativePath);
      if (!f.existsSync()) return null;
      return Uint8List.fromList(await f.readAsBytes());
    });
  }

  @override
  Future<void> deleteSnapshot(String relativePath) async {
    await _withAuth(() async {
      final f = _relFile(relativePath);
      if (f.existsSync()) await f.delete();
    });
  }

  @override
  Future<void> putRestoreWrap(Uint8List bytes) async {
    await _withAuth(() async {
      await _ensurePackDirs();
      final f = File(p.join(packRootPath, kVaultPackRestoreWrapFileName));
      await f.writeAsBytes(bytes, flush: true);
    });
  }

  @override
  Future<Uint8List?> getRestoreWrap() async {
    return _withAuth(() async {
      final f = File(p.join(packRootPath, kVaultPackRestoreWrapFileName));
      if (!f.existsSync()) return null;
      return Uint8List.fromList(await f.readAsBytes());
    });
  }

  @override
  Future<List<String>> listSnapshotPaths() async {
    return _withAuth(() async {
      final dir = Directory(p.join(packRootPath, kVaultPackSnapshotsDirName));
      if (!dir.existsSync()) return const [];
      final out = <String>[];
      for (final e in dir.listSync(followLinks: false)) {
        if (e is! File) continue;
        final name = p.basename(e.path);
        if (!name.endsWith('.bin')) continue;
        out.add('$kVaultPackSnapshotsDirName/$name');
      }
      out.sort();
      return out;
    });
  }

  @override
  Future<List<String>> listBlobIds() async {
    return _withAuth(() async {
      final dir = Directory(p.join(packRootPath, kVaultPackBlobsDirName));
      if (!dir.existsSync()) return const [];
      final out = <String>[];
      for (final e in dir.listSync(followLinks: false)) {
        if (e is! File) continue;
        final name = p.basename(e.path);
        if (name.length == 64) out.add(name.toLowerCase());
      }
      return out;
    });
  }

  /// Comprueba si existe un pack legible para [vaultId] bajo [rootDirectoryPath].
  static Future<bool> packExists({
    required String rootDirectoryPath,
    required String vaultId,
    bool folderRequiresAuth = false,
    String username = '',
    String password = '',
    String domain = '',
    SmbNetworkAuth? smbAuth,
  }) async {
    final t = FolderVaultPackTransport(
      rootDirectoryPath: rootDirectoryPath,
      vaultId: vaultId,
      folderRequiresAuth: folderRequiresAuth,
      username: username,
      password: password,
      domain: domain,
      smbAuth: smbAuth,
    );
    try {
      final meta = await t.readMeta();
      return meta != null;
    } catch (_) {
      return false;
    }
  }

  /// Lista ids de libreta con `meta.json` bajo `folio-packs/`.
  static Future<List<String>> listVaultIds({
    required String rootDirectoryPath,
    bool folderRequiresAuth = false,
    String username = '',
    String password = '',
    String domain = '',
    SmbNetworkAuth? smbAuth,
  }) async {
    final auth = smbAuth ?? SmbNetworkAuth();
    final out = <String>[];
    await auth.withConnection(
      path: rootDirectoryPath,
      folderRequiresAuth: folderRequiresAuth,
      username: username,
      password: password,
      domain: domain,
      action: () async {
        final packs = Directory(
          p.join(rootDirectoryPath.trim(), kVaultPackRootDirName),
        );
        if (!packs.existsSync()) return;
        for (final e in packs.listSync(followLinks: false)) {
          if (e is! Directory) continue;
          final id = p.basename(e.path).trim();
          if (id.isEmpty) continue;
          final meta = File(p.join(e.path, kVaultPackMetaFileName));
          if (meta.existsSync()) out.add(id);
        }
      },
    );
    out.sort();
    return out;
  }
}

/// Excepción tipada reutilizando [VaultBackupException].
typedef VaultPackException = VaultBackupException;
