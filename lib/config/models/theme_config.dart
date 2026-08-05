import 'package:json_annotation/json_annotation.dart';

import '../../app/folio_brand_palette.dart' show kFolioBrandPrimaryArgb;
import '../json_schema_version.dart';
import 'component_style_tokens.dart';
import 'semantic_color_tokens.dart';
import 'theme_layer_tokens.dart';
import 'theme_variant.dart';
import 'visual_style.dart';
import 'widget_theme_tokens.dart';
import 'theme_color_tokens.dart';
import 'theme_elevation_tokens.dart';
import 'theme_icon_tokens.dart';
import 'theme_motion_tokens.dart';
import 'theme_shape_tokens.dart';
import 'theme_spacing_tokens.dart';
import 'theme_typography_tokens.dart';

part 'theme_config.g.dart';

/// Configuración completa de tema: solo colores, tipografía, formas,
/// elevación, espaciado, movimiento, iconografía y transparencia. Nunca
/// contiene nada de layout (posiciones, tamaños de panel) — separación
/// estricta layout/tema del brief.
@JsonSerializable(explicitToJson: true)
class ThemeConfig {
  ThemeConfig({
    this.schemaVersion = kFolioConfigSchemaVersion,
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
    required this.typography,
    required this.shape,
    required this.elevation,
    required this.spacing,
    required this.motion,
    required this.icons,
    this.surfaceOpacity = 1.0,
    this.accentMode = 'followSystem',
    this.semanticColors,
    this.componentStyles,
    this.layers,
    this.variants,
    this.activeVariantId,
    this.visualStyle,
    this.widgetThemes,
  });

  final int schemaVersion;
  final String id;
  final String name;

  /// 'followSystem' | 'folioDefault' | 'custom' — mismo significado que
  /// `FolioAccentColorMode` en `AppSettings`, portado como dato en vez de
  /// enum Dart para que sea serializable sin un converter adicional.
  /// 'followSystem' y 'folioDefault' ignoran `light.seedArgb`/`dark.seedArgb`
  /// (resuelven el `ColorScheme` desde el acento del SO o desde
  /// `FolioBrandPalette` respectivamente); solo 'custom' los usa.
  final String accentMode;

  final ThemeColorTokens light;
  final ThemeColorTokens dark;
  final ThemeTypographyTokens typography;
  final ThemeShapeTokens shape;
  final ThemeElevationTokens elevation;
  final ThemeSpacingTokens spacing;
  final ThemeMotionTokens motion;
  final ThemeIconTokens icons;

  /// "Transparencia" del brief: 1.0 = superficies opacas, valores menores
  /// permiten estilos tipo Glass/macOS.
  final double surfaceOpacity;

  /// Roles de color con nombre más allá de `ColorScheme` (Fase 14). `null`
  /// = cada rol se deriva de `ColorScheme` como siempre (ver
  /// `semantic_colors_resolver.dart`).
  final SemanticColorTokens? semanticColors;

  /// Árbol de estilos por-componente más allá del radio (Fase 15). `null` =
  /// solo se aplica el escape hatch legacy `shape.componentRadiusOverrides`.
  final ComponentStyleTokens? componentStyles;

  /// Pila de capas surface/panel/overlay (Fase 18). `null` = cada slot de
  /// Material conserva su elevación/sombra literal de hoy.
  final ThemeLayerTokens? layers;

  /// Variantes disponibles de este tema (Fase 19) y cuál está activa. La
  /// fusión no se persiste por separado — se resuelve en tiempo de carga
  /// vía `resolveActiveVariant` (`theme_variant_resolver.dart`).
  final List<ThemeVariant>? variants;
  final String? activeVariantId;

  /// Densidad/glass/bordes/ventana/cursor/iconografía (Fase 20). `null` =
  /// cada slot conserva su literal de hoy.
  final VisualStyle? visualStyle;

  /// Tema semántico por-tipo-de-widget + Plugin Theme API (Fase 23).
  final WidgetThemeTokens? widgetThemes;

  factory ThemeConfig.fromJson(Map<String, dynamic> json) =>
      _$ThemeConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeConfigToJson(this);

  ThemeConfig copyWith({
    String? name,
    ThemeColorTokens? light,
    ThemeColorTokens? dark,
    ThemeTypographyTokens? typography,
    ThemeShapeTokens? shape,
    ThemeElevationTokens? elevation,
    ThemeSpacingTokens? spacing,
    ThemeMotionTokens? motion,
    ThemeIconTokens? icons,
    double? surfaceOpacity,
    String? accentMode,
    SemanticColorTokens? semanticColors,
    ComponentStyleTokens? componentStyles,
    ThemeLayerTokens? layers,
    List<ThemeVariant>? variants,
    String? activeVariantId,
    bool clearActiveVariantId = false,
    VisualStyle? visualStyle,
    WidgetThemeTokens? widgetThemes,
  }) {
    return ThemeConfig(
      schemaVersion: schemaVersion,
      id: id,
      name: name ?? this.name,
      light: light ?? this.light,
      dark: dark ?? this.dark,
      typography: typography ?? this.typography,
      shape: shape ?? this.shape,
      elevation: elevation ?? this.elevation,
      spacing: spacing ?? this.spacing,
      motion: motion ?? this.motion,
      icons: icons ?? this.icons,
      surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
      accentMode: accentMode ?? this.accentMode,
      semanticColors: semanticColors ?? this.semanticColors,
      componentStyles: componentStyles ?? this.componentStyles,
      layers: layers ?? this.layers,
      variants: variants ?? this.variants,
      activeVariantId: clearActiveVariantId
          ? null
          : (activeVariantId ?? this.activeVariantId),
      visualStyle: visualStyle ?? this.visualStyle,
      widgetThemes: widgetThemes ?? this.widgetThemes,
    );
  }

  /// Config mínima de arranque usada por [ConfigBootstrap] al migrar (Fase 1)
  /// cuando aún no existe ningún `ThemeConfig` guardado, y como default de
  /// `theme_config_defaults.dart` (Fase 3) — reproduce exactamente el
  /// comportamiento hoy hardcodeado en `AppSettings`/`folio_theme.dart`.
  factory ThemeConfig.fallbackDefault({
    String id = 'default',
    int? seedArgb,
    bool oled = false,
    String accentMode = 'followSystem',
  }) {
    final seed = seedArgb ?? kFolioBrandPrimaryArgb;
    return ThemeConfig(
      id: id,
      name: 'Folio',
      accentMode: accentMode,
      light: ThemeColorTokens(seedArgb: seed),
      dark: ThemeColorTokens(
        seedArgb: seed,
        surfaceStyle: oled ? 'oled' : 'standard',
      ),
      typography: ThemeTypographyTokens(),
      shape: ThemeShapeTokens(),
      elevation: ThemeElevationTokens(),
      spacing: ThemeSpacingTokens(),
      motion: ThemeMotionTokens(),
      icons: ThemeIconTokens(),
    );
  }
}
