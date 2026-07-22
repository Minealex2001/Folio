// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cloud_pack.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CloudPackManifest _$CloudPackManifestFromJson(Map<String, dynamic> json) =>
    CloudPackManifest(
      vaultId: json['vaultId'] as String,
      timestamp: (json['timestamp'] as num).toInt(),
      deviceId: json['deviceId'] as String,
      treeFormatVersion: (json['treeFormatVersion'] as num).toInt(),
      files: (json['files'] as List<dynamic>)
          .map((e) => CloudPackFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      snapshotId: json['snapshotId'] as String?,
      parentSnapshotId: json['parentSnapshotId'] as String?,
    );

Map<String, dynamic> _$CloudPackManifestToJson(CloudPackManifest instance) =>
    <String, dynamic>{
      'vaultId': instance.vaultId,
      'timestamp': instance.timestamp,
      'deviceId': instance.deviceId,
      'treeFormatVersion': instance.treeFormatVersion,
      'files': instance.files,
      'snapshotId': instance.snapshotId,
      'parentSnapshotId': instance.parentSnapshotId,
    };

CloudPackFile _$CloudPackFileFromJson(Map<String, dynamic> json) =>
    CloudPackFile(
      path: json['path'] as String,
      sha256: json['sha256'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      contentEncrypted: (json['contentEncrypted'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$CloudPackFileToJson(CloudPackFile instance) =>
    <String, dynamic>{
      'path': instance.path,
      'sha256': instance.sha256,
      'sizeBytes': instance.sizeBytes,
      'contentEncrypted': instance.contentEncrypted,
    };
