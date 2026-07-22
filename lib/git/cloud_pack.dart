/// Representación de un vault para subida a la nube (M3).
///
/// Contiene:
/// - Manifest: lista de archivos con SHA-256 y metadatos
/// - Bytes cifrados de cada archivo (por separado, no blob monolítico)
///
/// Content-addressed: cada archivo se encripta, se calcula SHA-256, y se sube
/// solo si no existe en el storage. Deduplicación automática.

import 'package:json_annotation/json_annotation.dart';

part 'cloud_pack.g.dart';

/// Manifest de un vault en la nube.
/// Lista todos los archivos y sus hashes para deduplicación.
@JsonSerializable()
class CloudPackManifest {
  CloudPackManifest({
    required this.vaultId,
    required this.timestamp,
    required this.deviceId,
    required this.treeFormatVersion,
    required this.files,
    this.snapshotId,
    this.parentSnapshotId,
  });

  /// ID de la libreta
  final String vaultId;

  /// Timestamp de creación (ms desde epoch)
  final int timestamp;

  /// Device que creó el manifest
  final String deviceId;

  /// Versión del formato (actualmente 1)
  final int treeFormatVersion;

  /// Lista de archivos en este pack
  final List<CloudPackFile> files;

  /// Snapshot ID asociado (opcional, para M3+)
  final String? snapshotId;

  /// Snapshot padre (para cadena de historiales)
  final String? parentSnapshotId;

  factory CloudPackManifest.fromJson(Map<String, dynamic> json) =>
      _$CloudPackManifestFromJson(json);

  Map<String, dynamic> toJson() {
    final base = _$CloudPackManifestToJson(this);
    // Ensure files are serialized as maps
    base['files'] = files.map((f) => f.toJson()).toList();
    return base;
  }
}

/// Representación de un archivo en el cloud pack.
@JsonSerializable()
class CloudPackFile {
  CloudPackFile({
    required this.path,
    required this.sha256,
    required this.sizeBytes,
    this.contentEncrypted,
  });

  /// Ruta relativa del archivo (ej: "pages/ab/abc123/blocks.jsonl")
  final String path;

  /// SHA-256 del contenido cifrado (para deduplicación)
  /// Sirve como ID único del archivo
  final String sha256;

  /// Tamaño en bytes
  final int sizeBytes;

  /// Contenido cifrado (solo se incluye si es nuevo)
  /// Si ya existe en storage (mismo sha256), es null
  final List<int>? contentEncrypted;

  factory CloudPackFile.fromJson(Map<String, dynamic> json) =>
      _$CloudPackFileFromJson(json);

  Map<String, dynamic> toJson() => _$CloudPackFileToJson(this);

  /// Indica si este archivo necesita ser subido (es nuevo)
  bool get needsUpload => contentEncrypted != null && contentEncrypted!.isNotEmpty;
}

/// Resultado de una operación de sync en la nube
class CloudSyncResult {
  CloudSyncResult({
    required this.success,
    required this.filesUploaded,
    required this.filesDeduped,
    required this.bytesUploaded,
    required this.bytesDeduped,
    this.error,
    this.remoteLockVersion,
  });

  /// Si la operación fue exitosa
  final bool success;

  /// Número de archivos nuevos subidos
  final int filesUploaded;

  /// Número de archivos deduplicados (ya existían)
  final int filesDeduped;

  /// Bytes realmente subidos (nuevos)
  final int bytesUploaded;

  /// Bytes ahorrados por deduplicación
  final int bytesDeduped;

  /// Error si falla
  final String? error;

  /// Lock version en servidor (para coordinación)
  final String? remoteLockVersion;
}
