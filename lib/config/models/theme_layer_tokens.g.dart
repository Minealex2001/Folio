// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_layer_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LayerStyle _$LayerStyleFromJson(Map<String, dynamic> json) => LayerStyle(
  shadow: json['shadow'] as bool? ?? false,
  border: json['border'] as bool? ?? false,
  opacity: const NullableTokenRefDoubleConverter().fromJson(json['opacity']),
  blurSigma: (json['blurSigma'] as num?)?.toDouble(),
);

Map<String, dynamic> _$LayerStyleToJson(
  LayerStyle instance,
) => <String, dynamic>{
  'shadow': instance.shadow,
  'border': instance.border,
  'opacity': const NullableTokenRefDoubleConverter().toJson(instance.opacity),
  'blurSigma': instance.blurSigma,
};

ThemeLayerTokens _$ThemeLayerTokensFromJson(Map<String, dynamic> json) =>
    ThemeLayerTokens(
      surface: json['surface'] == null
          ? const LayerStyle()
          : LayerStyle.fromJson(json['surface'] as Map<String, dynamic>),
      panel: json['panel'] == null
          ? const LayerStyle()
          : LayerStyle.fromJson(json['panel'] as Map<String, dynamic>),
      overlay: json['overlay'] == null
          ? const LayerStyle(shadow: true, opacity: TokenRef.literal(0.98))
          : LayerStyle.fromJson(json['overlay'] as Map<String, dynamic>),
      backgroundImageUrl: json['backgroundImageUrl'] as String?,
      backgroundImageOpacity: (json['backgroundImageOpacity'] as num?)
          ?.toDouble(),
      backgroundImageBlurSigma: (json['backgroundImageBlurSigma'] as num?)
          ?.toDouble(),
    );

Map<String, dynamic> _$ThemeLayerTokensToJson(ThemeLayerTokens instance) =>
    <String, dynamic>{
      'surface': instance.surface.toJson(),
      'panel': instance.panel.toJson(),
      'overlay': instance.overlay.toJson(),
      'backgroundImageUrl': instance.backgroundImageUrl,
      'backgroundImageOpacity': instance.backgroundImageOpacity,
      'backgroundImageBlurSigma': instance.backgroundImageBlurSigma,
    };
