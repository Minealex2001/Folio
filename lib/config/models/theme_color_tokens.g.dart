// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_color_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeColorTokens _$ThemeColorTokensFromJson(Map<String, dynamic> json) =>
    ThemeColorTokens(
      seedArgb: (json['seedArgb'] as num).toInt(),
      primaryArgb: (json['primaryArgb'] as num?)?.toInt(),
      secondaryArgb: (json['secondaryArgb'] as num?)?.toInt(),
      tertiaryArgb: (json['tertiaryArgb'] as num?)?.toInt(),
      errorArgb: (json['errorArgb'] as num?)?.toInt(),
      surfaceStyle: json['surfaceStyle'] as String? ?? 'standard',
    );

Map<String, dynamic> _$ThemeColorTokensToJson(ThemeColorTokens instance) =>
    <String, dynamic>{
      'seedArgb': instance.seedArgb,
      'primaryArgb': instance.primaryArgb,
      'secondaryArgb': instance.secondaryArgb,
      'tertiaryArgb': instance.tertiaryArgb,
      'errorArgb': instance.errorArgb,
      'surfaceStyle': instance.surfaceStyle,
    };
