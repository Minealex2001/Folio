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
    this.enabled = true,
    this.pageTransitionsEnabled = true,
    this.hoverEnabled = true,
    this.selectionEffectEnabled = true,
  });

  final int shortMs;
  final int short2Ms;
  final int mediumMs;
  final int themeChangeMs;
  final String curveName;

  /// Interruptor maestro (Fase 21/23 — reutilizado por
  /// `AccessibilityConfig.reduceMotion`, Fase 22): `false` fuerza
  /// duraciones a cero en cualquier sitio que lea `motion.enabled`.
  final bool enabled;

  /// Si `pageTransitionsTheme` usa `FadeForwardsPageTransitionsBuilder`
  /// (default, hoy) o una transición sin animación.
  final bool pageTransitionsEnabled;

  /// Reservado para animaciones de hover a nivel de widget que aún no leen
  /// este flag (ningún call site lo consume todavía — dato transportado
  /// para cuando lo hagan, mismo espíritu que otros flags aditivos de esta
  /// expansión).
  final bool hoverEnabled;

  /// Igual que [hoverEnabled] pero para efectos de selección.
  final bool selectionEffectEnabled;

  factory ThemeMotionTokens.fromJson(Map<String, dynamic> json) =>
      _$ThemeMotionTokensFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeMotionTokensToJson(this);
}
