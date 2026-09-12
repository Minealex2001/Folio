import 'package:json_annotation/json_annotation.dart';

part 'theme_color_tokens.g.dart';

/// Tokens de color para un brillo (light u dark) de un [ThemeConfig].
/// `surfaceStyle` reemplaza el antiguo booleano `oledThemeEnabled`: OLED es
/// un dato (un conjunto de overrides de superficie), no una rama de código
/// (ver Fase 3 — nunca `if (theme == oled)`).
@JsonSerializable()
class ThemeColorTokens {
  ThemeColorTokens({
    required this.seedArgb,
    this.primaryArgb,
    this.secondaryArgb,
    this.tertiaryArgb,
    this.errorArgb,
    this.surfaceStyle = 'standard',
  });

  final int seedArgb;
  final int? primaryArgb;
  final int? secondaryArgb;
  final int? tertiaryArgb;
  final int? errorArgb;

  /// 'standard' | 'oled'.
  final String surfaceStyle;

  bool get isOled => surfaceStyle == 'oled';

  factory ThemeColorTokens.fromJson(Map<String, dynamic> json) =>
      _$ThemeColorTokensFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeColorTokensToJson(this);
}
