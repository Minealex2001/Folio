/// Snapshot local de una libreta (representa estado en un punto en el tiempo).
///
/// M1: Reemplaza pageRevisions (que están en memoria en VaultPayload)
/// con snapshots persistentes en disco.

import 'package:json_annotation/json_annotation.dart';

part 'vault_snapshot.g.dart';

/// Metadatos de un snapshot local.
@JsonSerializable()
class VaultSnapshot {
  VaultSnapshot({
    required this.snapshotId,
    required this.createdAtMs,
    required this.deviceId,
    required this.treeFormatVersion,
    required this.fileManifest,
    this.label,
    this.parentSnapshotId,
  });

  /// ID único del snapshot (UUID).
  final String snapshotId;

  /// Timestamp de creación (ms desde epoch).
  final int createdAtMs;

  /// ID del dispositivo que lo creó.
  final String deviceId;

  /// Versión del formato de árbol (actualmente 1).
  /// Usado para coordinación multi-dispositivo (M2+).
  final int treeFormatVersion;

  /// Lista de archivos y sus hashes SHA-256.
  /// Ej: [
  ///   {"path": "tree.json", "sha256": "abc...", "sizeBytes": 1024},
  ///   {"path": "pages/ab/abc123/meta.json", "sha256": "def...", "sizeBytes": 256},
  ///   ...
  /// ]
  final List<FileManifestEntry> fileManifest;

  /// Etiqueta opcional del usuario (ej: "Before big refactor").
  final String? label;

  /// ID del snapshot anterior (para cadena de historiales).
  /// null = snapshot raíz.
  final String? parentSnapshotId;

  factory VaultSnapshot.fromJson(Map<String, dynamic> json) =>
      _$VaultSnapshotFromJson(json);

  Map<String, dynamic> toJson() => _$VaultSnapshotToJson(this);
}

/// Entrada en el manifest de archivos del snapshot.
@JsonSerializable()
class FileManifestEntry {
  FileManifestEntry({
    required this.path,
    required this.sha256,
    required this.sizeBytes,
  });

  /// Ruta relativa del archivo (ej: "pages/ab/abc123/blocks.jsonl").
  final String path;

  /// SHA-256 del contenido cifrado (para deduplicación).
  final String sha256;

  /// Tamaño en bytes.
  final int sizeBytes;

  factory FileManifestEntry.fromJson(Map<String, dynamic> json) =>
      _$FileManifestEntryFromJson(json);

  Map<String, dynamic> toJson() => _$FileManifestEntryToJson(this);
}
