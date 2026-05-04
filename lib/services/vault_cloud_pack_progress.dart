import '../data/folio_cloud_pack_format.dart';

/// Fase de la subida de un cloud-pack (copia incremental en la nube).
enum VaultCloudPackProgressStep {
  preparing,
  persisting,
  fingerprinting,
  fetchingMeta,
  skippedUpToDate,
  restoreWrap,
  /// Inventario de rutas locales (p. ej. adjuntos) antes de cifrar y subir.
  indexingLocal,
  downloadingPreviousManifest,
  uploadingBlob,
  uploadingSnapshot,
  finalizing,
  cleaningOldBlobs,
  updatingVaultIndex,
  complete,
}

/// Estado de progreso para la UI o telemetría.
class VaultCloudPackProgress {
  const VaultCloudPackProgress({
    required this.progress,
    required this.step,
    this.blobRole,
    this.attachmentRelativePath,
    this.blobsCompleted,
    this.blobsTotal,
  });

  /// Avance global aproximado entre 0 y 1.
  final double progress;
  final VaultCloudPackProgressStep step;
  final FolioCloudPackBlobRole? blobRole;
  final String? attachmentRelativePath;
  final int? blobsCompleted;
  final int? blobsTotal;
}

typedef OnVaultCloudPackProgress = void Function(VaultCloudPackProgress update);
