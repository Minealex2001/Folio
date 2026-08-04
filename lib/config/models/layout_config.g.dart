// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'layout_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LayoutConfig _$LayoutConfigFromJson(Map<String, dynamic> json) => LayoutConfig(
  schemaVersion:
      (json['schemaVersion'] as num?)?.toInt() ?? kFolioConfigSchemaVersion,
  id: json['id'] as String,
  name: json['name'] as String,
  panels: (json['panels'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, PanelConfig.fromJson(e as Map<String, dynamic>)),
  ),
  responsiveOverrides: (json['responsiveOverrides'] as Map<String, dynamic>?)
      ?.map(
        (k, e) => MapEntry(k, LayoutConfig.fromJson(e as Map<String, dynamic>)),
      ),
);

Map<String, dynamic> _$LayoutConfigToJson(LayoutConfig instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'id': instance.id,
      'name': instance.name,
      'panels': instance.panels.map((k, e) => MapEntry(k, e.toJson())),
      'responsiveOverrides': instance.responsiveOverrides?.map(
        (k, e) => MapEntry(k, e.toJson()),
      ),
    };
