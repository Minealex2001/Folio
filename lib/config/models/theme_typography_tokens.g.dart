// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_typography_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeTypographyTokens _$ThemeTypographyTokensFromJson(
  Map<String, dynamic> json,
) => ThemeTypographyTokens(
  fontFamily: json['fontFamily'] as String?,
  baseSizeScale: (json['baseSizeScale'] as num?)?.toDouble() ?? 1.0,
);

Map<String, dynamic> _$ThemeTypographyTokensToJson(
  ThemeTypographyTokens instance,
) => <String, dynamic>{
  'fontFamily': instance.fontFamily,
  'baseSizeScale': instance.baseSizeScale,
};
