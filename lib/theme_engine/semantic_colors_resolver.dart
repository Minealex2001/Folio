import 'package:flutter/material.dart';

import '../config/models/semantic_color_tokens.dart';
import '../config/models/token_ref.dart';
import 'design_tokens_resolver.dart';
import 'folio_semantic_colors.dart';

/// Resuelve [SemanticColorTokens] contra un [ColorScheme] ya resuelto (para
/// el brillo activo) a un [FolioSemanticColors] concreto. Cuando
/// [tokens]/un campo concreto es null, cada rol cae al mismo slot de
/// [ColorScheme] que hoy se usa de forma ad hoc en cada widget — documentado
/// campo a campo aquí para que sea auditable en un único sitio.
FolioSemanticColors resolveSemanticColors(
  SemanticColorTokens? tokens,
  ColorScheme scheme, {
  DesignTokensResolver? tokensResolver,
}) {
  Color resolve(TokenRef<int>? ref, Color fallback) {
    if (ref == null) return fallback;
    if (!ref.isReference) return Color(ref.literalValue!);
    if (tokensResolver == null) return fallback;
    return Color(tokensResolver.resolveColor(ref, fallback.toARGB32()));
  }

  return FolioSemanticColors(
    editorBackground: resolve(tokens?.editorBackground, scheme.surface),
    sidebarBackground: resolve(
      tokens?.sidebarBackground,
      scheme.surfaceContainerLow,
    ),
    sidebarHover: resolve(
      tokens?.sidebarHover,
      scheme.surfaceContainerHighest,
    ),
    sidebarSelection: resolve(
      tokens?.sidebarSelection,
      scheme.secondaryContainer,
    ),
    cardBackground: resolve(tokens?.cardBackground, scheme.surfaceContainerLow),
    panelBackground: resolve(tokens?.panelBackground, scheme.surfaceContainerLow),
    toolbarBackground: resolve(tokens?.toolbarBackground, Colors.transparent),
    windowBackground: resolve(tokens?.windowBackground, scheme.surface),
    canvasBackground: resolve(tokens?.canvasBackground, scheme.surface),
    selection: resolve(tokens?.selection, scheme.secondaryContainer),
    hover: resolve(
      tokens?.hover,
      scheme.onSurfaceVariant.withValues(alpha: 0.08),
    ),
    focus: resolve(tokens?.focus, scheme.primary),
    // warning/success/info no existen como conceptos en ColorScheme —
    // desplazados desde tertiary por HSL para quedar en la misma familia
    // tonal que el resto del tema en vez de un rojo/verde/azul hardcodeado.
    warning: resolve(tokens?.warning, _hueShift(scheme.tertiary, 40)),
    success: resolve(tokens?.success, _hueShift(scheme.tertiary, 130)),
    info: resolve(tokens?.info, _hueShift(scheme.tertiary, 220)),
  );
}

Color _hueShift(Color base, double targetHue) {
  final hsl = HSLColor.fromColor(base);
  return hsl.withHue(targetHue).toColor();
}
