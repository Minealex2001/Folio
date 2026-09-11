import 'package:json_annotation/json_annotation.dart';

part 'theme_shape_tokens.g.dart';

/// Radios de esquina. `componentRadiusOverrides` es el escape hatch por
/// componente descubierto trabajando hacia atrás desde el pack "Retro" de la
/// Fase 8 (algunos componentes angulosos, otros no) — se incorpora aquí en
/// Fase 1 en vez de como cambio de esquema posterior.
@JsonSerializable()
class ThemeShapeTokens {
  ThemeShapeTokens({
    this.radiusXs = 4,
    this.radiusSm = 8,
    this.radiusMd = 12,
    this.radiusLg = 16,
    this.radiusXl = 24,
    this.radiusXxl = 32,
    this.componentRadiusOverrides,
  });

  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusXxl;

  /// Key = nombre semántico de componente (ej. 'button', 'card', 'chip').
  final Map<String, double>? componentRadiusOverrides;

  factory ThemeShapeTokens.fromJson(Map<String, dynamic> json) =>
      _$ThemeShapeTokensFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeShapeTokensToJson(this);
}
