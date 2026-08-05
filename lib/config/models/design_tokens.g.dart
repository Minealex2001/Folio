// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'design_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesignTokens _$DesignTokensFromJson(Map<String, dynamic> json) => DesignTokens(
  schemaVersion:
      (json['schemaVersion'] as num?)?.toInt() ?? kFolioConfigSchemaVersion,
  id: json['id'] as String? ?? 'default',
  radius:
      (json['radius'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ) ??
      const {},
  space:
      (json['space'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ) ??
      const {},
  color:
      (json['color'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  opacity:
      (json['opacity'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ) ??
      const {},
  motionMs:
      (json['motionMs'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  size:
      (json['size'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ) ??
      const {},
);

Map<String, dynamic> _$DesignTokensToJson(DesignTokens instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'id': instance.id,
      'radius': instance.radius,
      'space': instance.space,
      'color': instance.color,
      'opacity': instance.opacity,
      'motionMs': instance.motionMs,
      'size': instance.size,
    };
