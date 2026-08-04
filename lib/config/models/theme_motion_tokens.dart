import 'package:json_annotation/json_annotation.dart';

part 'theme_motion_tokens.g.dart';

/// Duraciones en ms + nombre de curva (resuelto a [Curve] por
/// `theme_motion_resolver.dart`, Fase 3, para no acoplar el modelo a
/// `package:flutter`).
@JsonSerializable()
class ThemeMotionTokens {
  ThemeMotionTokens({
    this.shortMs = 120,
    this.short2Ms = 200,
    this.mediumMs = 280,
    this.themeChangeMs = 300,
    this.curveName = 'easeOutCubic',
  });

  final int shortMs;
  final int short2Ms;
  final int mediumMs;
  final int themeChangeMs;
  final String curveName;

  factory ThemeMotionTokens.fromJson(Map<String, dynamic> json) =>
      _$ThemeMotionTokensFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeMotionTokensToJson(this);
}
