// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'component_state_style.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComponentStateStyle _$ComponentStateStyleFromJson(
  Map<String, dynamic> json,
) => ComponentStateStyle(
  hover: json['hover'] == null
      ? null
      : ComponentStyleEntry.fromJson(json['hover'] as Map<String, dynamic>),
  pressed: json['pressed'] == null
      ? null
      : ComponentStyleEntry.fromJson(json['pressed'] as Map<String, dynamic>),
  focused: json['focused'] == null
      ? null
      : ComponentStyleEntry.fromJson(json['focused'] as Map<String, dynamic>),
  disabled: json['disabled'] == null
      ? null
      : ComponentStyleEntry.fromJson(json['disabled'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ComponentStateStyleToJson(
  ComponentStateStyle instance,
) => <String, dynamic>{
  'hover': instance.hover?.toJson(),
  'pressed': instance.pressed?.toJson(),
  'focused': instance.focused?.toJson(),
  'disabled': instance.disabled?.toJson(),
};
