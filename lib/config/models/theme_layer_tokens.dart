import 'package:json_annotation/json_annotation.dart';

import 'token_ref.dart';

part 'theme_layer_tokens.g.dart';

/// Estilo de una capa visual: sombra/borde/transparencia/blur propios
/// (Fase 18, punto 8 del brief).
@JsonSerializable(explicitToJson: true)
class LayerStyle {
  const LayerStyle({
    this.shadow = false,
    this.border = false,
    this.opacity,
    this.blurSigma,
  });

  final bool shadow;
  final bool border;

  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? opacity;

  /// null = sin blur de backdrop.
  final double? blurSigma;

  factory LayerStyle.fromJson(Map<String, dynamic> json) =>
      _$LayerStyleFromJson(json);

  Map<String, dynamic> toJson() => _$LayerStyleToJson(this);
}

/// Pila de capas reducida a 3 niveles configurables (Fase 18, tras feedback
/// directo: "no veo claro que un usuario vaya a distinguir entre Floating y
/// Dialog") — de los 7 conceptos originales (Background/Surface/Panel/
/// Card/Floating/Dialog/Overlay), solo Surface/Panel/Overlay son
/// user-facing; `card` se resuelve contra `surface` con su propio
/// `ComponentStyleEntry.border` (Fase 15), y floating/dialog/menu contra
/// `overlay`. Cada componente de Material conserva su elevación literal de
/// hoy como default y solo se re-parametriza si `overlay` está configurado
/// explícitamente (ver `theme_resolver.dart`).
@JsonSerializable(explicitToJson: true)
class ThemeLayerTokens {
  const ThemeLayerTokens({
    this.surface = const LayerStyle(),
    this.panel = const LayerStyle(),
    this.overlay = const LayerStyle(shadow: true, opacity: TokenRef.literal(0.98)),
    this.backgroundImageUrl,
    this.backgroundImageOpacity,
    this.backgroundImageBlurSigma,
  });

  final LayerStyle surface;
  final LayerStyle panel;
  final LayerStyle overlay;

  /// Anexo: fondo del canvas (imagen/blur/opacidad detrás del contenido).
  final String? backgroundImageUrl;
  final double? backgroundImageOpacity;
  final double? backgroundImageBlurSigma;

  factory ThemeLayerTokens.fromJson(Map<String, dynamic> json) =>
      _$ThemeLayerTokensFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeLayerTokensToJson(this);
}
