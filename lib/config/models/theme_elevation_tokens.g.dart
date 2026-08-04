// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_elevation_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeElevationTokens _$ThemeElevationTokensFromJson(
  Map<String, dynamic> json,
) => ThemeElevationTokens(
  none: (json['none'] as num?)?.toDouble() ?? 0,
  appBarScrolled: (json['appBarScrolled'] as num?)?.toDouble() ?? 1,
  menu: (json['menu'] as num?)?.toDouble() ?? 4,
  shadowOpacity: (json['shadowOpacity'] as num?)?.toDouble() ?? 0.08,
);

Map<String, dynamic> _$ThemeElevationTokensToJson(
  ThemeElevationTokens instance,
) => <String, dynamic>{
  'none': instance.none,
  'appBarScrolled': instance.appBarScrolled,
  'menu': instance.menu,
  'shadowOpacity': instance.shadowOpacity,
};
