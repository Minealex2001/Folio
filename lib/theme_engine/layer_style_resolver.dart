import 'package:flutter/material.dart';

import '../config/models/theme_layer_tokens.dart';
import 'design_tokens_resolver.dart';

/// Nombres válidos de capa (Fase 18) — `'surface'|'panel'|'overlay'`.
LayerStyle resolveLayer(ThemeLayerTokens tokens, String layerName) {
  switch (layerName) {
    case 'surface':
      return tokens.surface;
    case 'panel':
      return tokens.panel;
    case 'overlay':
      return tokens.overlay;
    default:
      return const LayerStyle();
  }
}

/// Construye una `BoxDecoration` a partir de un [LayerStyle] resuelto —
/// para superficies no-Material (sidebar, paneles flotantes) que necesitan
/// pintar fondo/borde/sombra ellas mismas, ya que `ThemeData` no tiene un
/// slot para "esta superficie concreta usa transparencia/blur".
BoxDecoration decorationFor(
  LayerStyle style,
  ColorScheme scheme,
  Color backgroundColor, {
  DesignTokensResolver? tokensResolver,
  double borderRadius = 0,
}) {
  final opacityRef = style.opacity;
  final alpha = opacityRef == null
      ? 1.0
      : (opacityRef.isReference
            ? (tokensResolver?.resolveDouble(opacityRef, 1.0) ?? 1.0)
            : opacityRef.literalValue!);

  return BoxDecoration(
    color: alpha >= 0.999
        ? backgroundColor
        : backgroundColor.withValues(alpha: alpha.clamp(0.0, 1.0)),
    borderRadius: BorderRadius.circular(borderRadius),
    border: style.border
        ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3))
        : null,
    boxShadow: style.shadow
        ? [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
        : null,
  );
}
