// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_instance_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WidgetInstanceConfig _$WidgetInstanceConfigFromJson(
  Map<String, dynamic> json,
) => WidgetInstanceConfig(
  schemaVersion:
      (json['schemaVersion'] as num?)?.toInt() ?? kFolioConfigSchemaVersion,
  instanceId: json['instanceId'] as String,
  pluginId: json['pluginId'] as String,
  regionId: json['regionId'] as String,
  order: (json['order'] as num?)?.toInt() ?? 0,
  width: (json['width'] as num?)?.toDouble(),
  height: (json['height'] as num?)?.toDouble(),
  visible: json['visible'] as bool? ?? true,
  groupId: json['groupId'] as String?,
  settings: json['settings'] as Map<String, dynamic>? ?? const {},
  capabilityOverrides: json['capabilityOverrides'] == null
      ? null
      : WidgetCapabilityOverrides.fromJson(
          json['capabilityOverrides'] as Map<String, dynamic>,
        ),
  appearance: json['appearance'] == null
      ? null
      : WidgetAppearanceConfig.fromJson(
          json['appearance'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$WidgetInstanceConfigToJson(
  WidgetInstanceConfig instance,
) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'instanceId': instance.instanceId,
  'pluginId': instance.pluginId,
  'regionId': instance.regionId,
  'order': instance.order,
  'width': instance.width,
  'height': instance.height,
  'visible': instance.visible,
  'groupId': instance.groupId,
  'settings': instance.settings,
  'capabilityOverrides': instance.capabilityOverrides?.toJson(),
  'appearance': instance.appearance?.toJson(),
};
