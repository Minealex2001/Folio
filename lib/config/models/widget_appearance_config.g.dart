// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_appearance_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WidgetAppearanceConfig _$WidgetAppearanceConfigFromJson(
  Map<String, dynamic> json,
) => WidgetAppearanceConfig(
  backgroundColorArgb: (json['backgroundColorArgb'] as num?)?.toInt(),
  opacity: (json['opacity'] as num?)?.toDouble(),
  border: json['border'] as bool?,
  shadow: json['shadow'] as bool?,
  cornerRadius: (json['cornerRadius'] as num?)?.toDouble(),
);

Map<String, dynamic> _$WidgetAppearanceConfigToJson(
  WidgetAppearanceConfig instance,
) => <String, dynamic>{
  'backgroundColorArgb': instance.backgroundColorArgb,
  'opacity': instance.opacity,
  'border': instance.border,
  'shadow': instance.shadow,
  'cornerRadius': instance.cornerRadius,
};
