import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../../data/vault_backup.dart';
import 'vault_pack_meta.dart';
import 'vault_pack_paths.dart';
import 'vault_pack_transport.dart';

/// Pack incremental sobre WebDAV.
class WebDavVaultPackTransport implements VaultPackTransport {
  WebDavVaultPackTransport({
    required this.baseUrl,
    required this.remotePath,
    required this.username,
    required this.password,
    required this.vaultId,
  });

  final String baseUrl;
  final String remotePath;
  final String username;
  final String password;
  final String vaultId;

  @override
  String get label => _packRootRemote();

  webdav.Client _client() {
    final url = baseUrl.trim();
    if (url.isEmpty) {
      throw VaultBackupException('La URL de WebDAV no está configurada.');
    }
    final client = webdav.newClient(
      url.endsWith('/') ? url : '$url/',
      user: username.trim(),
      password: password,
    );
    client.setConnectTimeout(15000);
    client.setSendTimeout(120000);
    client.setReceiveTimeout(120000);
    return client;
  }

  String _normalizedRemoteDir() {
    var dir = remotePath.trim().replaceAll(r'\', '/');
    if (!dir.startsWith('/')) dir = '/$dir';
    while (dir.length > 1 && dir.endsWith('/')) {
      dir = dir.substring(0, dir.length - 1);
    }
    return dir;
  }

  String _packRootRemote() {
    final vid = vaultId.trim();
    return '${_normalizedRemoteDir()}/$kVaultPackRootDirName/$vid';
  }

  String _remote(String relativePosix) {
    final rel = relativePosix.replaceAll(r'\', '/');
    final cleaned = rel.startsWith('/') ? rel.substring(1) : rel;
    return '${_packRootRemote()}/$cleaned';
  }

  Future<void> _ensureDir(webdav.Client client, String dirPath) async {
    try {
      await client.mkdir(dirPath);
    } catch (_) {}
  }

  Future<void> _ensurePackDirs(webdav.Client client) async {
    await _ensureDir(client, _normalizedRemoteDir());
    await _ensureDir(
      client,
      '${_normalizedRemoteDir()}/$kVaultPackRootDirName',
    );
    await _ensureDir(client, _packRootRemote());
    await _ensureDir(client, _remote(kVaultPackBlobsDirName));
    await _ensureDir(client, _remote(kVaultPackSnapshotsDirName));
  }

  @override
  Future<VaultPackMeta?> readMeta() async {
    final client = _client();
    try {
      final bytes = await client.read(_remote(kVaultPackMetaFileName));
      if (bytes.isEmpty) return null;
      return VaultPackMeta.fromJsonBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeMeta(VaultPackMeta meta) async {
    final client = _client();
    await _ensurePackDirs(client);
    try {
      await client.write(
        _remote(kVaultPackMetaFileName),
        Uint8List.fromList(meta.toUtf8Bytes()),
      );
    } catch (e) {
      throw VaultBackupException('No se pudo escribir meta.json: $e');
    }
  }

  @override
  Future<bool> blobExists(String blobId) async {
    final client = _client();
    try {
      await client.readProps(_remote('$kVaultPackBlobsDirName/$blobId'));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> putBlob(String blobId, Uint8List bytes) async {
    if (await blobExists(blobId)) return;
    final client = _client();
    await _ensurePackDirs(client);
    try {
      await client.write(
        _remote('$kVaultPackBlobsDirName/$blobId'),
        bytes,
      );
    } catch (e) {
      throw VaultBackupException('No se pudo subir blob $blobId: $e');
    }
  }

  @override
  Future<Uint8List?> getBlob(String blobId) async {
    final client = _client();
    try {
      final bytes = await client.read(
        _remote('$kVaultPackBlobsDirName/$blobId'),
      );
      if (bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteBlob(String blobId) async {
    final client = _client();
    try {
      await client.remove(_remote('$kVaultPackBlobsDirName/$blobId'));
    } catch (_) {}
  }

  @override
  Future<void> putSnapshot(String relativePath, Uint8List bytes) async {
    final client = _client();
    await _ensurePackDirs(client);
    try {
      await client.write(_remote(relativePath), bytes);
    } catch (e) {
      throw VaultBackupException('No se pudo subir snapshot: $e');
    }
  }

  @override
  Future<Uint8List?> getSnapshot(String relativePath) async {
    final client = _client();
    try {
      final bytes = await client.read(_remote(relativePath));
      if (bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteSnapshot(String relativePath) async {
    final client = _client();
    try {
      await client.remove(_remote(relativePath));
    } catch (_) {}
  }

  @override
  Future<void> putRestoreWrap(Uint8List bytes) async {
    final client = _client();
    await _ensurePackDirs(client);
    try {
      await client.write(_remote(kVaultPackRestoreWrapFileName), bytes);
    } catch (e) {
      throw VaultBackupException('No se pudo guardar restore_wrap: $e');
    }
  }

  @override
  Future<Uint8List?> getRestoreWrap() async {
    final client = _client();
    try {
      final bytes = await client.read(_remote(kVaultPackRestoreWrapFileName));
      if (bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> listSnapshotPaths() async {
    final client = _client();
    final out = <String>[];
    try {
      final listing = await client.readDir(
        _remote(kVaultPackSnapshotsDirName),
      );
      for (final item in listing) {
        if (item.isDir == true) continue;
        final name = p.basename(item.path ?? '');
        if (name.isEmpty || !name.endsWith('.bin')) continue;
        out.add('$kVaultPackSnapshotsDirName/$name');
      }
    } catch (_) {}
    out.sort();
    return out;
  }

  @override
  Future<List<String>> listBlobIds() async {
    final client = _client();
    final out = <String>[];
    try {
      final listing = await client.readDir(_remote(kVaultPackBlobsDirName));
      for (final item in listing) {
        if (item.isDir == true) continue;
        final name = p.basename(item.path ?? '').toLowerCase();
        if (name.length == 64) out.add(name);
      }
    } catch (_) {}
    return out;
  }

  static Future<List<String>> listVaultIds({
    required String baseUrl,
    required String remotePath,
    required String username,
    required String password,
  }) async {
    final probe = WebDavVaultPackTransport(
      baseUrl: baseUrl,
      remotePath: remotePath,
      username: username,
      password: password,
      vaultId: '_',
    );
    final client = probe._client();
    final root =
        '${probe._normalizedRemoteDir()}/$kVaultPackRootDirName';
    final out = <String>[];
    try {
      await probe._ensureDir(client, probe._normalizedRemoteDir());
      await probe._ensureDir(client, root);
      final listing = await client.readDir(root);
      for (final item in listing) {
        if (item.isDir != true) continue;
        final id = p.basename(item.path ?? '').trim();
        if (id.isEmpty || id == '_') continue;
        final t = WebDavVaultPackTransport(
          baseUrl: baseUrl,
          remotePath: remotePath,
          username: username,
          password: password,
          vaultId: id,
        );
        final meta = await t.readMeta();
        if (meta != null) out.add(id);
      }
    } catch (_) {}
    out.sort();
    return out;
  }
}
