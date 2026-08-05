// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeConfig _$ThemeConfigFromJson(Map<String, dynamic> json) => ThemeConfig(
  schemaVersion:
      (json['schemaVersion'] as num?)?.toInt() ?? kFolioConfigSchemaVersion,
  id: json['id'] as String,
  name: json['name'] as String,
  light: ThemeColorTokens.fromJson(json['light'] as Map<String, dynamic>),
  dark: ThemeColorTokens.fromJson(json['dark'] as Map<String, dynamic>),
  typography: ThemeTypographyTokens.fromJson(
    json['typography'] as Map<String, dynamic>,
  ),
  shape: ThemeShapeTokens.fromJson(json['shape'] as Map<String, dynamic>),
  elevation: ThemeElevationTokens.fromJson(
    json['elevation'] as Map<String, dynamic>,
  ),
  spacing: ThemeSpacingTokens.fromJson(json['spacing'] as Map<String, dynamic>),
  motion: ThemeMotionTokens.fromJson(json['motion'] as Map<String, dynamic>),
  icons: ThemeIconTokens.fromJson(json['icons'] as Map<String, dynamic>),
  surfaceOpacity: (json['surfaceOpacity'] as num?)?.toDouble() ?? 1.0,
  accentMode: json['accentMode'] as String? ?? 'followSystem',
  semanticColors: json['semanticColors'] == null
      ? null
      : SemanticColorTokens.fromJson(
          json['semanticColors'] as Map<String, dynamic>,
        ),
  componentStyles: json['componentStyles'] == null
      ? null
      : ComponentStyleTokens.fromJson(
          json['componentStyles'] as Map<String, dynamic>,
        ),
  layers: json['layers'] == null
      ? null
      : ThemeLayerTokens.fromJson(json['layers'] as Map<String, dynamic>),
  variants: (json['variants'] as List<dynamic>?)
      ?.map((e) => ThemeVariant.fromJson(e as Map<String, dynamic>))
      .toList(),
  activeVariantId: json['activeVariantId'] as String?,
  visualStyle: json['visualStyle'] == null
      ? null
      : VisualStyle.fromJson(json['visualStyle'] as Map<String, dynamic>),
  widgetThemes: json['widgetThemes'] == null
      ? null
      : WidgetThemeTokens.fromJson(
          json['widgetThemes'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$ThemeConfigToJson(ThemeConfig instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'id': instance.id,
      'name': instance.name,
      'accentMode': instance.accentMode,
      'light': instance.light.toJson(),
      'dark': instance.dark.toJson(),
      'typography': instance.typography.toJson(),
      'shape': instance.shape.toJson(),
      'elevation': instance.elevation.toJson(),
      'spacing': instance.spacing.toJson(),
      'motion': instance.motion.toJson(),
      'icons': instance.icons.toJson(),
      'surfaceOpacity': instance.surfaceOpacity,
      'semanticColors': instance.semanticColors?.toJson(),
      'componentStyles': instance.componentStyles?.toJson(),
      'layers': instance.layers?.toJson(),
      'variants': instance.variants?.map((e) => e.toJson()).toList(),
      'activeVariantId': instance.activeVariantId,
      'visualStyle': instance.visualStyle?.toJson(),
      'widgetThemes': instance.widgetThemes?.toJson(),
    };
