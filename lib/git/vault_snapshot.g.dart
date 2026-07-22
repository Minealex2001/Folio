// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VaultSnapshot _$VaultSnapshotFromJson(Map<String, dynamic> json) =>
    VaultSnapshot(
      snapshotId: json['snapshotId'] as String,
      createdAtMs: (json['createdAtMs'] as num).toInt(),
      deviceId: json['deviceId'] as String,
      treeFormatVersion: (json['treeFormatVersion'] as num).toInt(),
      fileManifest: (json['fileManifest'] as List<dynamic>)
          .map((e) => FileManifestEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      label: json['label'] as String?,
      parentSnapshotId: json['parentSnapshotId'] as String?,
    );

Map<String, dynamic> _$VaultSnapshotToJson(VaultSnapshot instance) =>
    <String, dynamic>{
      'snapshotId': instance.snapshotId,
      'createdAtMs': instance.createdAtMs,
      'deviceId': instance.deviceId,
      'treeFormatVersion': instance.treeFormatVersion,
      'fileManifest': instance.fileManifest,
      'label': instance.label,
      'parentSnapshotId': instance.parentSnapshotId,
    };

FileManifestEntry _$FileManifestEntryFromJson(Map<String, dynamic> json) =>
    FileManifestEntry(
      path: json['path'] as String,
      sha256: json['sha256'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
    );

Map<String, dynamic> _$FileManifestEntryToJson(FileManifestEntry instance) =>
    <String, dynamic>{
      'path': instance.path,
      'sha256': instance.sha256,
      'sizeBytes': instance.sizeBytes,
    };
