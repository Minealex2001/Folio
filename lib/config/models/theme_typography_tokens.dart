import 'package:json_annotation/json_annotation.dart';

part 'theme_typography_tokens.g.dart';

@JsonSerializable()
class ThemeTypographyTokens {
  ThemeTypographyTokens({this.fontFamily, this.baseSizeScale = 1.0});

  /// Familia tipográfica; null = usa el default de la app (Outfit vía
  /// google_fonts hoy — ver `theme_config_defaults.dart`, Fase 3).
  final String? fontFamily;
  final double baseSizeScale;

  factory ThemeTypographyTokens.fromJson(Map<String, dynamic> json) =>
      _$ThemeTypographyTokensFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeTypographyTokensToJson(this);
}
