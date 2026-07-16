import 'dart:io';

/// Entrada de copia listada en un destino remoto o de red.
class RemoteBackupEntry {
  const RemoteBackupEntry({
    required this.name,
    this.modifiedAt,
    this.sizeBytes,
    this.isIncrementalPack = false,
    this.packVaultId,
  });

  final String name;
  final DateTime? modifiedAt;
  final int? sizeBytes;

  /// Copia pack incremental (`folio-packs/<vaultId>/`), no un ZIP.
  final bool isIncrementalPack;

  /// Id de libreta del pack cuando [isIncrementalPack] es true.
  final String? packVaultId;
}

/// Destino de copia de seguridad (carpeta local/UNC o WebDAV).
abstract class BackupDestination {
  String get label;

  Future<void> ping();

  Future<void> uploadZip(File zipFile, String fileName);

  Future<List<RemoteBackupEntry>> listZipBackups();

  Future<void> download(String fileName, File dest);

  Future<void> pruneOld(int keepN);
}

/// Nombres de archivo de copia reconocidos por Folio.
bool isFolioBackupZipName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.zip') &&
      (lower.startsWith('folio-scheduled-') ||
          lower.startsWith('folio-backup-'));
}

String scheduledVaultBackupFileName({DateTime? at}) {
  final stamp = (at ?? DateTime.now())
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-');
  final base = stamp.contains('.') ? stamp.split('.').first : stamp;
  return 'folio-scheduled-$base.zip';
}
