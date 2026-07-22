/// Pack de sincronización P2P para el nuevo formato (M4).
///
/// Contiene:
/// - Manifest del árbol (lista de archivos + SHA-256)
/// - Árbol comprimido (ZIP) para transporte eficiente
/// - Metadatos (deviceId, snapshot info)
///
/// El pack se comprime para P2P (red local) y se encripta con AES-256-GCM.

import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'p2p_sync_pack.g.dart';

/// Header de un pack de sync P2P.
@JsonSerializable()
class P2PSyncPackHeader {
  P2PSyncPackHeader({
    required this.vaultId,
    required this.formatVersion,
    required this.timestamp,
    required this.sourceDeviceId,
    required this.treeFormatVersion,
    required this.fileCount,
    required this.compressedSizeBytes,
    required this.uncompressedSizeBytes,
    this.snapshotId,
    this.snapshotLabel,
  });

  /// Vault ID
  final String vaultId;

  /// Versión del pack P2P (para compatibilidad futura)
  final int formatVersion;

  /// Timestamp de creación
  final int timestamp;

  /// Dispositivo origen
  final String sourceDeviceId;

  /// Versión del árbol (0=viejo, 1=nuevo)
  final int treeFormatVersion;

  /// Número de archivos en el pack
  final int fileCount;

  /// Tamaño después de comprimir (ZIP)
  final int compressedSizeBytes;

  /// Tamaño sin comprimir
  final int uncompressedSizeBytes;

  /// Snapshot ID (si existe)
  final String? snapshotId;

  /// Etiqueta legible del snapshot
  final String? snapshotLabel;

  factory P2PSyncPackHeader.fromJson(Map<String, dynamic> json) =>
      _$P2PSyncPackHeaderFromJson(json);

  Map<String, dynamic> toJson() => _$P2PSyncPackHeaderToJson(this);

  /// Ratio de compresión
  double get compressionRatio =>
      uncompressedSizeBytes > 0
          ? (1.0 - (compressedSizeBytes / uncompressedSizeBytes))
          : 0.0;
}

/// Resultado de un sync P2P
class P2PSyncResult {
  P2PSyncResult({
    required this.success,
    required this.vaultId,
    required this.filesSynced,
    required this.bytesSynced,
    required this.compressionRatio,
    this.error,
  });

  final bool success;
  final String vaultId;
  final int filesSynced;
  final int bytesSynced;
  final double compressionRatio;
  final String? error;

  String get compressionPercentage =>
      '${(compressionRatio * 100).toStringAsFixed(1)}%';
}

/// Estadísticas de un pack de sync
class P2PSyncStats {
  P2PSyncStats({
    required this.uncompressed,
    required this.compressed,
    required this.fileCount,
    required this.duration,
  });

  /// Tamaño sin comprimir
  final int uncompressed;

  /// Tamaño con comprimir
  final int compressed;

  /// Número de archivos
  final int fileCount;

  /// Duración del sync en ms
  final int duration;

  double get compressionRatio =>
      uncompressed > 0 ? (1.0 - (compressed / uncompressed)) : 0.0;

  double get throughputMBps =>
      duration > 0 ? (uncompressed / (1024 * 1024 * duration / 1000)) : 0.0;

  @override
  String toString() =>
      'P2PSyncStats(files=$fileCount, '
      'uncompressed=${(uncompressed / 1024 / 1024).toStringAsFixed(1)}MB, '
      'compressed=${(compressed / 1024 / 1024).toStringAsFixed(1)}MB, '
      'ratio=${(compressionRatio * 100).toStringAsFixed(1)}%, '
      'throughput=${throughputMBps.toStringAsFixed(1)}MB/s)';
}
