import 'package:json_annotation/json_annotation.dart';

import 'component_style_tokens.dart';

part 'component_state_style.g.dart';

/// Overlay de estados (Hover/Pressed/Focused/Disabled) sobre el estilo base
/// de un componente (Fase 17) — reutiliza [ComponentStyleEntry] como forma
/// para cada estado, así que no es un sistema paralelo: es el mismo modelo
/// de la Fase 15, condicionado por estado de interacción.
@JsonSerializable(explicitToJson: true)
class ComponentStateStyle {
  const ComponentStateStyle({this.hover, this.pressed, this.focused, this.disabled});

  final ComponentStyleEntry? hover;
  final ComponentStyleEntry? pressed;
  final ComponentStyleEntry? focused;
  final ComponentStyleEntry? disabled;

  factory ComponentStateStyle.fromJson(Map<String, dynamic> json) =>
      _$ComponentStateStyleFromJson(json);

  Map<String, dynamic> toJson() => _$ComponentStateStyleToJson(this);
}
