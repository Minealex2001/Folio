// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_capability_overrides.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WidgetCapabilityOverrides _$WidgetCapabilityOverridesFromJson(
  Map<String, dynamic> json,
) => WidgetCapabilityOverrides(
  movable: json['movable'] as bool?,
  resizable: json['resizable'] as bool?,
  duplicable: json['duplicable'] as bool?,
  closable: json['closable'] as bool?,
  detachable: json['detachable'] as bool?,
);

Map<String, dynamic> _$WidgetCapabilityOverridesToJson(
  WidgetCapabilityOverrides instance,
) => <String, dynamic>{
  'movable': instance.movable,
  'resizable': instance.resizable,
  'duplicable': instance.duplicable,
  'closable': instance.closable,
  'detachable': instance.detachable,
};
