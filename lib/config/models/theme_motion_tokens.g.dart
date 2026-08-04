// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_motion_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeMotionTokens _$ThemeMotionTokensFromJson(Map<String, dynamic> json) =>
    ThemeMotionTokens(
      shortMs: (json['shortMs'] as num?)?.toInt() ?? 120,
      short2Ms: (json['short2Ms'] as num?)?.toInt() ?? 200,
      mediumMs: (json['mediumMs'] as num?)?.toInt() ?? 280,
      themeChangeMs: (json['themeChangeMs'] as num?)?.toInt() ?? 300,
      curveName: json['curveName'] as String? ?? 'easeOutCubic',
    );

Map<String, dynamic> _$ThemeMotionTokensToJson(ThemeMotionTokens instance) =>
    <String, dynamic>{
      'shortMs': instance.shortMs,
      'short2Ms': instance.short2Ms,
      'mediumMs': instance.mediumMs,
      'themeChangeMs': instance.themeChangeMs,
      'curveName': instance.curveName,
    };
