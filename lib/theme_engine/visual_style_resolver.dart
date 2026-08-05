import 'package:flutter/material.dart';

import '../config/models/token_ref.dart';
import '../config/models/visual_style.dart';
import 'design_tokens_resolver.dart';

/// Nombres de cursor conocidos, con fallback de nombre desconocido — mismo
/// patrón que `resolveMotionCurve` en `theme_resolver.dart`.
MouseCursor resolveCursor(VisualStyle? style, String slot) {
  final name = switch (slot) {
    'hover' => style?.cursorHover ?? 'basic',
    'resize' => style?.cursorResize ?? 'resizeColumn',
    'text' => style?.cursorText ?? 'text',
    _ => 'basic',
  };
  switch (name) {
    case 'basic':
      return SystemMouseCursors.basic;
    case 'click':
      return SystemMouseCursors.click;
    case 'text':
      return SystemMouseCursors.text;
    case 'resizeColumn':
      return SystemMouseCursors.resizeColumn;
    case 'resizeRow':
      return SystemMouseCursors.resizeRow;
    case 'resizeUpDown':
      return SystemMouseCursors.resizeUpDown;
    case 'resizeLeftRight':
      return SystemMouseCursors.resizeLeftRight;
    case 'grab':
      return SystemMouseCursors.grab;
    case 'grabbing':
      return SystemMouseCursors.grabbing;
    case 'forbidden':
      return SystemMouseCursors.forbidden;
    default:
      return SystemMouseCursors.basic;
  }
}

/// 'compact' (default, reproduce el `VisualDensity(-1,-1)` de hoy) |
/// 'comfortable' | 'spacious'. `densityScale` NO se aplica aquí — es un
/// multiplicador consumido directamente donde `theme_resolver.dart`
/// construye `EdgeInsets` (`VisualDensity` de Flutter es una escala
/// discreta, no un factor continuo).
VisualDensity resolveDensity(VisualStyle? style) {
  switch (style?.densityMode ?? 'compact') {
    case 'comfortable':
      return const VisualDensity(horizontal: 0, vertical: 0);
    case 'spacious':
      return const VisualDensity(horizontal: 1, vertical: 1);
    case 'compact':
    default:
      return const VisualDensity(horizontal: -1, vertical: -1);
  }
}

double resolveDensityScale(VisualStyle? style) => style?.densityScale ?? 1.0;

double _resolveOpacityRef(
  TokenRef<double>? ref,
  double fallback,
  DesignTokensResolver? tokensResolver,
) {
  if (ref == null) return fallback;
  if (!ref.isReference) return ref.literalValue!;
  return tokensResolver?.resolveDouble(ref, fallback) ?? fallback;
}

/// Opacidad de superficie por-tipo ('sidebar'|'dialog'|'menu'|'panel'),
/// cayendo a `surfaceOpacityFallback` (`ThemeConfig.surfaceOpacity`, que
/// **no se renombra ni se borra**) cuando no está configurada.
double resolveGlassOpacity(
  VisualStyle? style,
  String surfaceName,
  double surfaceOpacityFallback, {
  DesignTokensResolver? tokensResolver,
}) {
  final ref = switch (surfaceName) {
    'sidebar' => style?.glassSidebarOpacity,
    'dialog' => style?.glassDialogOpacity,
    'menu' => style?.glassMenuOpacity,
    'panel' => style?.glassPanelOpacity,
    _ => null,
  };
  return _resolveOpacityRef(ref, surfaceOpacityFallback, tokensResolver);
}

/// null cuando `borderEnabled` es false (default) — ningún call site debe
/// dibujar un borde global no pedido.
BorderSide? resolveGlobalBorder(
  VisualStyle? style,
  ColorScheme scheme, {
  DesignTokensResolver? tokensResolver,
}) {
  if (style == null || !style.borderEnabled) return null;
  final width = _resolveOpacityRef(style.borderWidth, 1.0, tokensResolver);
  final opacity = _resolveOpacityRef(style.borderOpacity, 0.5, tokensResolver);
  return BorderSide(
    color: scheme.outlineVariant.withValues(alpha: opacity.clamp(0.0, 1.0)),
    width: width,
  );
}

/// Aplica solo lo que `IconThemeData` realmente soporta (`size`) — `null`
/// (sin configurar) devuelve [base] sin tocar. `iconStyle`/`iconStrokeWidth`
/// se guardan como dato pero Flutter no tiene un slot estándar en
/// `IconThemeData` para variar el grosor de trazo de un `IconData` fijo
/// (a diferencia de una fuente de icono variable) — documentado en vez de
/// fingir soporte que no existe.
IconThemeData resolveIconTheme(
  VisualStyle? style,
  IconThemeData base, {
  DesignTokensResolver? tokensResolver,
}) {
  final sizeRef = style?.iconSize;
  if (sizeRef == null) return base;
  final size = sizeRef.isReference
      ? (tokensResolver?.resolveDouble(sizeRef, base.size ?? 24) ?? base.size ?? 24)
      : sizeRef.literalValue!;
  return base.copyWith(size: size);
}
