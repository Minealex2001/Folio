// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolbar_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToolbarConfig _$ToolbarConfigFromJson(Map<String, dynamic> json) =>
    ToolbarConfig(
      visible: json['visible'] as bool? ?? true,
      position: json['position'] as String? ?? 'top',
      floatingX: (json['floatingX'] as num?)?.toDouble(),
      floatingY: (json['floatingY'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble() ?? 64,
    );

Map<String, dynamic> _$ToolbarConfigToJson(ToolbarConfig instance) =>
    <String, dynamic>{
      'visible': instance.visible,
      'position': instance.position,
      'floatingX': instance.floatingX,
      'floatingY': instance.floatingY,
      'height': instance.height,
    };
