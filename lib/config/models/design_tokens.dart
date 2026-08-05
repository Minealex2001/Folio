import 'package:json_annotation/json_annotation.dart';

import '../json_schema_version.dart';

part 'design_tokens.g.dart';

/// Valores de token con nombre, planos y tipados por categoría (Fase 12).
/// Cada mapa es "nombre corto -> valor literal" — `radius['lg']`,
/// `color['accent']`, etc. Nunca contiene [TokenRef] anidados: el *valor* de
/// un token siempre es literal, solo los *consumidores* de tokens (formas,
/// estilos de componente, variables) usan [TokenRef] para referenciarlos.
@JsonSerializable(explicitToJson: true)
class DesignTokens {
  DesignTokens({
    this.schemaVersion = kFolioConfigSchemaVersion,
    this.id = 'default',
    this.radius = const {},
    this.space = const {},
    this.color = const {},
    this.opacity = const {},
    this.motionMs = const {},
    this.size = const {},
  });

  final int schemaVersion;
  final String id;

  /// ej. "xs".."xxl" — mismos nombres que [ThemeShapeTokens] hoy, más
  /// cualquier nombre custom que el usuario añada.
  final Map<String, double> radius;

  /// ej. "xxs".."xl" — mismos nombres que `ThemeSpacingTokens` hoy.
  final Map<String, double> space;

  /// ARGB, ej. "surface", "danger", "accent".
  final Map<String, int> color;

  /// 0..1, ej. "glassLight", "glassHeavy".
  final Map<String, double> opacity;

  /// Duraciones en milisegundos, ej. "fast", "medium".
  final Map<String, int> motionMs;

  /// Tamaños varios no cubiertos por radius/space (icono, ancho de cursor…).
  final Map<String, double> size;

  factory DesignTokens.fromJson(Map<String, dynamic> json) =>
      _$DesignTokensFromJson(json);

  Map<String, dynamic> toJson() => _$DesignTokensToJson(this);

  DesignTokens copyWith({
    Map<String, double>? radius,
    Map<String, double>? space,
    Map<String, int>? color,
    Map<String, double>? opacity,
    Map<String, int>? motionMs,
    Map<String, double>? size,
  }) {
    return DesignTokens(
      schemaVersion: schemaVersion,
      id: id,
      radius: radius ?? this.radius,
      space: space ?? this.space,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      motionMs: motionMs ?? this.motionMs,
      size: size ?? this.size,
    );
  }
}
