import 'dart:ui';

import 'package:flutter/material.dart';

import '../../config/models/theme_layer_tokens.dart';
import '../../theme_engine/design_tokens_resolver.dart';
import '../../theme_engine/layer_style_resolver.dart';

/// Wrapper reutilizable para superficies no-Material (sidebar, paneles
/// flotantes) que necesitan aplicar de verdad blur/opacidad/sombra/borde de
/// una capa (Fase 18) — `Card`/`Material` ya lo hacen vía `ThemeData`
/// (`dialogTheme`/`popupMenuTheme` en `theme_resolver.dart`), pero widgets
/// fuera de ese sistema no tienen otro sitio donde pintarlo.
///
/// [style] se resuelve upstream vía `resolveLayer(themeConfig.layers,
/// layerName)` — este widget es solo la primitiva de render, no hace
/// resolución de config por sí mismo.
class LayerSurface extends StatelessWidget {
  const LayerSurface({
    super.key,
    required this.style,
    required this.backgroundColor,
    required this.child,
    this.borderRadius = 0,
    this.tokensResolver,
  });

  final LayerStyle style;
  final Color backgroundColor;
  final Widget child;
  final double borderRadius;
  final DesignTokensResolver? tokensResolver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decoration = decorationFor(
      style,
      scheme,
      backgroundColor,
      tokensResolver: tokensResolver,
      borderRadius: borderRadius,
    );

    Widget content = DecoratedBox(decoration: decoration, child: child);

    final blurSigma = style.blurSigma;
    if (blurSigma != null && blurSigma > 0) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    }
    return content;
  }
}
