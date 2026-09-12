// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_shape_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeShapeTokens _$ThemeShapeTokensFromJson(Map<String, dynamic> json) =>
    ThemeShapeTokens(
      radiusXs: (json['radiusXs'] as num?)?.toDouble() ?? 4,
      radiusSm: (json['radiusSm'] as num?)?.toDouble() ?? 8,
      radiusMd: (json['radiusMd'] as num?)?.toDouble() ?? 12,
      radiusLg: (json['radiusLg'] as num?)?.toDouble() ?? 16,
      radiusXl: (json['radiusXl'] as num?)?.toDouble() ?? 24,
      radiusXxl: (json['radiusXxl'] as num?)?.toDouble() ?? 32,
      componentRadiusOverrides:
          (json['componentRadiusOverrides'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toDouble()),
          ),
    );

Map<String, dynamic> _$ThemeShapeTokensToJson(ThemeShapeTokens instance) =>
    <String, dynamic>{
      'radiusXs': instance.radiusXs,
      'radiusSm': instance.radiusSm,
      'radiusMd': instance.radiusMd,
      'radiusLg': instance.radiusLg,
      'radiusXl': instance.radiusXl,
      'radiusXxl': instance.radiusXxl,
      'componentRadiusOverrides': instance.componentRadiusOverrides,
    };
