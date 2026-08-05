import 'package:json_annotation/json_annotation.dart';

import 'component_state_style.dart';
import 'token_ref.dart';

part 'component_style_tokens.g.dart';

/// Estilo de un componente con nombre (Fase 15, generaliza el precedente ya
/// existente de `ThemeShapeTokens.componentRadiusOverrides` — radio por
/// componente — a un puñado más de propiedades por-componente sin volverse
/// theming exhaustivo por-propiedad).
@JsonSerializable(explicitToJson: true)
class ComponentStyleEntry {
  const ComponentStyleEntry({
    this.radius,
    this.border,
    this.shadow,
    this.backgroundColor,
    this.opacity,
    this.states,
  });

  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? radius;

  /// Si aplica el borde del token global (`VisualStyle.border`, Fase 20).
  final bool? border;

  /// Si aplica la sombra por defecto de la capa que lo contiene
  /// (`ThemeLayerTokens`, Fase 18).
  final bool? shadow;

  @NullableTokenRefIntConverter()
  final TokenRef<int>? backgroundColor;

  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? opacity;

  /// Overlay por-estado (Fase 17) — solo se consulta para la lista curada
  /// de componentes interactivos (`kInteractiveComponentKeys` en
  /// `component_state_resolver.dart`); para el resto se ignora aunque esté
  /// presente en el JSON.
  final ComponentStateStyle? states;

  factory ComponentStyleEntry.fromJson(Map<String, dynamic> json) =>
      _$ComponentStyleEntryFromJson(json);

  Map<String, dynamic> toJson() => _$ComponentStyleEntryToJson(this);
}

/// Árbol de estilos por-componente, indexado por nombre semántico (ej.
/// 'button', 'dialog', 'sidebar', 'card' — los mismos nombres ya usados en
/// `ThemeShapeTokens.componentRadiusOverrides` y en las llamadas a
/// `radius(...)` de `theme_resolver.dart`).
@JsonSerializable(explicitToJson: true)
class ComponentStyleTokens {
  const ComponentStyleTokens({this.components = const {}});

  final Map<String, ComponentStyleEntry> components;

  factory ComponentStyleTokens.fromJson(Map<String, dynamic> json) =>
      _$ComponentStyleTokensFromJson(json);

  Map<String, dynamic> toJson() => _$ComponentStyleTokensToJson(this);
}
