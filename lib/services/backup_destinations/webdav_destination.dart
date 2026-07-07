import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../../data/vault_backup.dart';
import 'backup_destination.dart';

/// Copias en servidor WebDAV (NAS Ugreen y similares).
class WebDavDestination implements BackupDestination {
  WebDavDestination({
    required this.baseUrl,
    required this.remotePath,
    required this.username,
    required this.password,
  });

  final String baseUrl;
  final String remotePath;
  final String username;
  final String password;

  @override
  String get label => _clientRoot();

  webdav.Client _client() {
    final url = baseUrl.trim();
    if (url.isEmpty) {
      throw VaultBackupException('La URL de WebDAV no está configurada.');
    }
    return webdav.newClient(
      url.endsWith('/') ? url : '$url/',
      user: username.trim(),
      password: password,
    );
  }

  String _normalizedRemoteDir() {
    var dir = remotePath.trim().replaceAll(r'\', '/');
    if (!dir.startsWith('/')) dir = '/$dir';
    while (dir.length > 1 && dir.endsWith('/')) {
      dir = dir.substring(0, dir.length - 1);
    }
    return dir;
  }

  String _clientRoot() {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base${_normalizedRemoteDir()}';
  }

  String _remoteFilePath(String fileName) {
    return '${_normalizedRemoteDir()}/$fileName';
  }

  Future<void> _ensureRemoteDir(webdav.Client client) async {
    final dir = _normalizedRemoteDir();
    try {
      await client.mkdir(dir);
    } catch (_) {
      // Ya existe o el servidor no requiere MKCOL previo.
    }
  }

  @override
  Future<void> ping() async {
    if (username.trim().isEmpty) {
      throw VaultBackupException('Se requiere usuario de WebDAV.');
    }
    final client = _client();
    try {
      await _ensureRemoteDir(client);
      final probeName = '.folio-write-test';
      final remote = '${_normalizedRemoteDir()}/$probeName';
      await client.write(remote, Uint8List.fromList('ok'.codeUnits));
      try {
        await client.remove(remote);
      } catch (_) {}
    } on VaultBackupException {
      rethrow;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('403')) {
        throw VaultBackupException(
          'Credenciales WebDAV incorrectas o acceso denegado.',
        );
      }
      throw VaultBackupException('No se pudo conectar por WebDAV: $e');
    }
  }

  @override
  Future<void> uploadZip(File zipFile, String fileName) async {
    final client = _client();
    await _ensureRemoteDir(client);
    final bytes = await zipFile.readAsBytes();
    try {
      await client.write(_remoteFilePath(fileName), Uint8List.fromList(bytes));
    } catch (e) {
      throw VaultBackupException('No se pudo subir la copia por WebDAV: $e');
    }
  }

  @override
  Future<List<RemoteBackupEntry>> listZipBackups() async {
    final client = _client();
    final dir = _normalizedRemoteDir();
    final out = <RemoteBackupEntry>[];
    try {
      final listing = await client.readDir(dir);
      for (final item in listing) {
        final name = p.basename(item.path ?? '');
        if (name.isEmpty || !isFolioBackupZipName(name)) continue;
        if (item.isDir == true) continue;
        DateTime? modified = item.mTime;
        out.add(
          RemoteBackupEntry(
            name: name,
            modifiedAt: modified,
            sizeBytes: item.size,
          ),
        );
      }
    } catch (e) {
      throw VaultBackupException('No se pudo listar copias en WebDAV: $e');
    }
    out.sort((a, b) {
      final am = a.modifiedAt?.millisecondsSinceEpoch ?? 0;
      final bm = b.modifiedAt?.millisecondsSinceEpoch ?? 0;
      return bm.compareTo(am);
    });
    return out;
  }

  @override
  Future<void> download(String fileName, File dest) async {
    final client = _client();
    try {
      final bytes = await client.read(_remoteFilePath(fileName));
      await dest.writeAsBytes(Uint8List.fromList(bytes), flush: true);
    } catch (e) {
      throw VaultBackupException('No se pudo descargar la copia: $e');
    }
  }

  @override
  Future<void> pruneOld(int keepN) async {
    if (keepN <= 0) return;
    final entries = await listZipBackups();
    if (entries.length <= keepN) return;
    final client = _client();
    for (final entry in entries.skip(keepN)) {
      try {
        await client.remove(_remoteFilePath(entry.name));
      } catch (_) {}
    }
  }
}
