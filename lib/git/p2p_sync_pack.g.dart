// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'p2p_sync_pack.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

P2PSyncPackHeader _$P2PSyncPackHeaderFromJson(Map<String, dynamic> json) =>
    P2PSyncPackHeader(
      vaultId: json['vaultId'] as String,
      formatVersion: (json['formatVersion'] as num).toInt(),
      timestamp: (json['timestamp'] as num).toInt(),
      sourceDeviceId: json['sourceDeviceId'] as String,
      treeFormatVersion: (json['treeFormatVersion'] as num).toInt(),
      fileCount: (json['fileCount'] as num).toInt(),
      compressedSizeBytes: (json['compressedSizeBytes'] as num).toInt(),
      uncompressedSizeBytes: (json['uncompressedSizeBytes'] as num).toInt(),
      snapshotId: json['snapshotId'] as String?,
      snapshotLabel: json['snapshotLabel'] as String?,
    );

Map<String, dynamic> _$P2PSyncPackHeaderToJson(P2PSyncPackHeader instance) =>
    <String, dynamic>{
      'vaultId': instance.vaultId,
      'formatVersion': instance.formatVersion,
      'timestamp': instance.timestamp,
      'sourceDeviceId': instance.sourceDeviceId,
      'treeFormatVersion': instance.treeFormatVersion,
      'fileCount': instance.fileCount,
      'compressedSizeBytes': instance.compressedSizeBytes,
      'uncompressedSizeBytes': instance.uncompressedSizeBytes,
      'snapshotId': instance.snapshotId,
      'snapshotLabel': instance.snapshotLabel,
    };
