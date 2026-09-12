// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_variant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeVariant _$ThemeVariantFromJson(Map<String, dynamic> json) => ThemeVariant(
  id: json['id'] as String,
  name: json['name'] as String,
  light: json['light'] == null
      ? null
      : ThemeColorTokens.fromJson(json['light'] as Map<String, dynamic>),
  dark: json['dark'] == null
      ? null
      : ThemeColorTokens.fromJson(json['dark'] as Map<String, dynamic>),
  typography: json['typography'] == null
      ? null
      : ThemeTypographyTokens.fromJson(
          json['typography'] as Map<String, dynamic>,
        ),
  shape: json['shape'] == null
      ? null
      : ThemeShapeTokens.fromJson(json['shape'] as Map<String, dynamic>),
  elevation: json['elevation'] == null
      ? null
      : ThemeElevationTokens.fromJson(
          json['elevation'] as Map<String, dynamic>,
        ),
  spacing: json['spacing'] == null
      ? null
      : ThemeSpacingTokens.fromJson(json['spacing'] as Map<String, dynamic>),
  motion: json['motion'] == null
      ? null
      : ThemeMotionTokens.fromJson(json['motion'] as Map<String, dynamic>),
  icons: json['icons'] == null
      ? null
      : ThemeIconTokens.fromJson(json['icons'] as Map<String, dynamic>),
  surfaceOpacity: (json['surfaceOpacity'] as num?)?.toDouble(),
  accentMode: json['accentMode'] as String?,
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
);

Map<String, dynamic> _$ThemeVariantToJson(ThemeVariant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'light': instance.light?.toJson(),
      'dark': instance.dark?.toJson(),
      'typography': instance.typography?.toJson(),
      'shape': instance.shape?.toJson(),
      'elevation': instance.elevation?.toJson(),
      'spacing': instance.spacing?.toJson(),
      'motion': instance.motion?.toJson(),
      'icons': instance.icons?.toJson(),
      'surfaceOpacity': instance.surfaceOpacity,
      'accentMode': instance.accentMode,
      'semanticColors': instance.semanticColors?.toJson(),
      'componentStyles': instance.componentStyles?.toJson(),
      'layers': instance.layers?.toJson(),
    };
