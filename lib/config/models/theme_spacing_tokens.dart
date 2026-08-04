import 'package:json_annotation/json_annotation.dart';

part 'theme_spacing_tokens.g.dart';

@JsonSerializable()
class ThemeSpacingTokens {
  ThemeSpacingTokens({
    this.xxs = 4,
    this.xs = 8,
    this.sm = 12,
    this.md = 16,
    this.lg = 24,
    this.xl = 40,
  });

  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  factory ThemeSpacingTokens.fromJson(Map<String, dynamic> json) =>
      _$ThemeSpacingTokensFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeSpacingTokensToJson(this);
}
