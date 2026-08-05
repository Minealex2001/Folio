// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accessibility_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccessibilityConfig _$AccessibilityConfigFromJson(Map<String, dynamic> json) =>
    AccessibilityConfig(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? kFolioConfigSchemaVersion,
      contrast: json['contrast'] as String? ?? 'normal',
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      largeHitTargets: json['largeHitTargets'] as bool? ?? false,
    );

Map<String, dynamic> _$AccessibilityConfigToJson(
  AccessibilityConfig instance,
) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'contrast': instance.contrast,
  'reduceMotion': instance.reduceMotion,
  'largeHitTargets': instance.largeHitTargets,
};
