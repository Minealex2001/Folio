// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'panel_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PanelConfig _$PanelConfigFromJson(Map<String, dynamic> json) => PanelConfig(
  regionId: json['regionId'] as String,
  visible: json['visible'] as bool? ?? true,
  width: (json['width'] as num?)?.toDouble(),
  height: (json['height'] as num?)?.toDouble(),
  floatingX: (json['floatingX'] as num?)?.toDouble(),
  floatingY: (json['floatingY'] as num?)?.toDouble(),
  locked: json['locked'] as bool? ?? false,
  order: (json['order'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PanelConfigToJson(PanelConfig instance) =>
    <String, dynamic>{
      'regionId': instance.regionId,
      'visible': instance.visible,
      'width': instance.width,
      'height': instance.height,
      'floatingX': instance.floatingX,
      'floatingY': instance.floatingY,
      'locked': instance.locked,
      'order': instance.order,
    };
