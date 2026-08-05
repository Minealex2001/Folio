import 'package:flutter/material.dart';

import '../config/models/component_state_style.dart';
import '../config/models/component_style_tokens.dart';
import 'design_tokens_resolver.dart';

/// Componentes genuinamente interactivos para los que [ComponentStateStyle]
/// se consulta de verdad (Fase 17, alcance reducido tras feedback: "solo lo
/// haría para componentes interactivos", no cada componente del árbol de
/// estilos). Ampliar esta lista es un cambio de una línea, no una migración.
const Set<String> kInteractiveComponentKeys = {
  'button',
  'iconButton',
  'filledButton',
  'outlinedButton',
  'textButton',
  'tab',
  'menuItem',
  'listTile',
  'sidebarItem',
  'toggle',
  'chip',
};

/// Resuelve el `ComponentStyleEntry` efectivo para un componente interactivo
/// dado un conjunto de [WidgetState] — fusiona el estilo base con el overlay
/// del estado que corresponda (prioridad pressed > hover > focused >
/// disabled). Para componentes fuera de [kInteractiveComponentKeys], o sin
/// `states` configurado, devuelve null (el call site usa su default de
/// siempre).
class ComponentStateResolver {
  const ComponentStateResolver(this.componentStyles, {this.tokensResolver});

  final ComponentStyleTokens? componentStyles;
  final DesignTokensResolver? tokensResolver;

  ComponentStyleEntry? styleForState(String componentName, Set<WidgetState> states) {
    if (!kInteractiveComponentKeys.contains(componentName)) return null;
    final stateStyle = componentStyles?.components[componentName]?.states;
    if (stateStyle == null) return null;
    return _pick(stateStyle, states);
  }

  ComponentStyleEntry? _pick(ComponentStateStyle stateStyle, Set<WidgetState> states) {
    if (states.contains(WidgetState.pressed) && stateStyle.pressed != null) {
      return stateStyle.pressed;
    }
    if (states.contains(WidgetState.hovered) && stateStyle.hover != null) {
      return stateStyle.hover;
    }
    if (states.contains(WidgetState.focused) && stateStyle.focused != null) {
      return stateStyle.focused;
    }
    if (states.contains(WidgetState.disabled) && stateStyle.disabled != null) {
      return stateStyle.disabled;
    }
    return null;
  }

  /// Color de fondo efectivo para [componentName] en [states], o [fallback]
  /// si no hay override de estado configurado.
  Color? backgroundColorForState(
    String componentName,
    Set<WidgetState> states, {
    Color? fallback,
  }) {
    final ref = styleForState(componentName, states)?.backgroundColor;
    if (ref == null) return fallback;
    if (!ref.isReference) return Color(ref.literalValue!);
    final resolved = tokensResolver?.resolveColor(ref, fallback?.toARGB32() ?? 0);
    return resolved == null ? fallback : Color(resolved);
  }
}
