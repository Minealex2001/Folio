import 'package:json_annotation/json_annotation.dart';

import 'component_style_tokens.dart';
import 'semantic_color_tokens.dart';
import 'theme_color_tokens.dart';
import 'theme_elevation_tokens.dart';
import 'theme_icon_tokens.dart';
import 'theme_layer_tokens.dart';
import 'theme_motion_tokens.dart';
import 'theme_shape_tokens.dart';
import 'theme_spacing_tokens.dart';
import 'theme_typography_tokens.dart';

part 'theme_variant.g.dart';

/// Variante de un tema base sin cambiar de tema completo (Fase 19, punto 13
/// del brief — ej. Aurora→Morning→Warm / Aurora→Night→OLED).
///
/// **Fusión tipada, no JSON dinámico** — rediseñado tras feedback explícito
/// del usuario ("los merges JSON acaban siendo difíciles de depurar"). Cada
/// campo espeja uno de [ThemeConfig] pero es nullable — `null` = "hereda del
/// tema base sin tocar", un valor no-null gana. `applyVariant` (en
/// `theme_variant_resolver.dart`) es literalmente `base.copyWith(...)`,
/// reutilizando el mecanismo ya existente y compilador-verificado en vez de
/// un motor de fusión nuevo o un recorrido de `Map<String, dynamic>`.
///
/// Nota de alcance: esto es reemplazo de sub-árbol completo (ej. una
/// variante que fija `shape` reemplaza TODO `ThemeShapeTokens`, no solo el
/// campo que a uno le interese), igual que ya hacen los packs visuales al
/// reemplazar `light`/`dark` — no fusión campo-a-campo dentro de cada
/// sub-árbol. Suficiente para el caso de uso del brief (variantes de color/
/// superficie); si en el futuro hiciera falta fusión más fina, es una
/// extensión aditiva, no una reescritura.
@JsonSerializable(explicitToJson: true)
class ThemeVariant {
  const ThemeVariant({
    required this.id,
    required this.name,
    this.light,
    this.dark,
    this.typography,
    this.shape,
    this.elevation,
    this.spacing,
    this.motion,
    this.icons,
    this.surfaceOpacity,
    this.accentMode,
    this.semanticColors,
    this.componentStyles,
    this.layers,
  });

  final String id;
  final String name;

  final ThemeColorTokens? light;
  final ThemeColorTokens? dark;
  final ThemeTypographyTokens? typography;
  final ThemeShapeTokens? shape;
  final ThemeElevationTokens? elevation;
  final ThemeSpacingTokens? spacing;
  final ThemeMotionTokens? motion;
  final ThemeIconTokens? icons;
  final double? surfaceOpacity;
  final String? accentMode;
  final SemanticColorTokens? semanticColors;
  final ComponentStyleTokens? componentStyles;
  final ThemeLayerTokens? layers;

  factory ThemeVariant.fromJson(Map<String, dynamic> json) =>
      _$ThemeVariantFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeVariantToJson(this);
}
