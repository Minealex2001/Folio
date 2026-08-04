// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardConfig _$DashboardConfigFromJson(Map<String, dynamic> json) =>
    DashboardConfig(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? kFolioConfigSchemaVersion,
      id: json['id'] as String,
      name: json['name'] as String,
      columns: (json['columns'] as num?)?.toInt() ?? 2,
      gap: (json['gap'] as num?)?.toDouble() ?? 16,
      widgets:
          (json['widgets'] as List<dynamic>?)
              ?.map(
                (e) => WidgetInstanceConfig.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DashboardConfigToJson(DashboardConfig instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'id': instance.id,
      'name': instance.name,
      'columns': instance.columns,
      'gap': instance.gap,
      'widgets': instance.widgets.map((e) => e.toJson()).toList(),
    };
