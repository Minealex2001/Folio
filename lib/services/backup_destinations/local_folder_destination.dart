import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/vault_backup.dart';
import 'backup_destination.dart';
import 'smb_network_auth.dart';

const String kFolioBackupWriteTestFile = '.folio-write-test';

/// Copias en carpeta local, unidad montada o ruta UNC (SMB en Windows).
class LocalFolderDestination implements BackupDestination {
  LocalFolderDestination({
    required this.directoryPath,
    this.folderRequiresAuth = false,
    this.username = '',
    this.password = '',
    this.domain = '',
    SmbNetworkAuth? smbAuth,
  }) : _smbAuth = smbAuth ?? SmbNetworkAuth();

  final String directoryPath;
  final bool folderRequiresAuth;
  final String username;
  final String password;
  final String domain;
  final SmbNetworkAuth _smbAuth;

  @override
  String get label => directoryPath;

  Directory get _directory => Directory(directoryPath.trim());

  Future<void> _withAuth(Future<void> Function() action) {
    return _smbAuth.withConnection(
      path: directoryPath,
      folderRequiresAuth: folderRequiresAuth,
      username: username,
      password: password,
      domain: domain,
      action: action,
    );
  }

  Future<void> _ensureDirectory() async {
    final dir = _directory;
    if (!dir.existsSync()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        throw VaultBackupException('No se pudo crear la carpeta: $e');
      }
    }
  }

  @override
  Future<void> ping() async {
    await _withAuth(() async {
      await _ensureDirectory();
      final testFile = File(p.join(directoryPath, kFolioBackupWriteTestFile));
      try {
        await testFile.writeAsString('ok', flush: true);
        if (testFile.existsSync()) {
          await testFile.delete();
        }
      } catch (e) {
        throw VaultBackupException('No se pudo escribir en la carpeta: $e');
      }
    });
  }

  @override
  Future<void> uploadZip(File zipFile, String fileName) async {
    await _withAuth(() async {
      await _ensureDirectory();
      final dest = File(p.join(directoryPath, fileName));
      try {
        await zipFile.copy(dest.path);
      } catch (e) {
        throw VaultBackupException('No se pudo guardar la copia: $e');
      }
    });
  }

  @override
  Future<List<RemoteBackupEntry>> listZipBackups() async {
    final out = <RemoteBackupEntry>[];
    await _withAuth(() async {
      final dir = _directory;
      if (!dir.existsSync()) return;
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!isFolioBackupZipName(name)) continue;
        final stat = entity.statSync();
        out.add(
          RemoteBackupEntry(
            name: name,
            modifiedAt: stat.modified,
            sizeBytes: stat.size,
          ),
        );
      }
    });
    out.sort((a, b) {
      final am = a.modifiedAt?.millisecondsSinceEpoch ?? 0;
      final bm = b.modifiedAt?.millisecondsSinceEpoch ?? 0;
      return bm.compareTo(am);
    });
    return out;
  }

  @override
  Future<void> download(String fileName, File dest) async {
    await _withAuth(() async {
      final src = File(p.join(directoryPath, fileName));
      if (!src.existsSync()) {
        throw VaultBackupException('No se encontró la copia: $fileName');
      }
      await src.copy(dest.path);
    });
  }

  @override
  Future<void> pruneOld(int keepN) async {
    if (keepN <= 0) return;
    await _withAuth(() async {
      final entries = await listZipBackups();
      if (entries.length <= keepN) return;
      for (final entry in entries.skip(keepN)) {
        try {
          final f = File(p.join(directoryPath, entry.name));
          if (f.existsSync()) await f.delete();
        } catch (_) {}
      }
    });
  }
}
