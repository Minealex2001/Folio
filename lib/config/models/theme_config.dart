import 'package:json_annotation/json_annotation.dart';

import '../../app/folio_brand_palette.dart' show kFolioBrandPrimaryArgb;
import '../json_schema_version.dart';
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
  });

  final int schemaVersion;
  final String id;
  final String name;

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
    );
  }

  /// Config mínima de arranque usada por [ConfigBootstrap] al migrar (Fase 1)
  /// cuando aún no existe ningún `ThemeConfig` guardado. Reproducir el
  /// `ThemeData` exacto de hoy (`_folioThemeFromBase`) es responsabilidad de
  /// `theme_config_defaults.dart` (Fase 3) — esta factory solo garantiza que
  /// `ConfigStore` siempre tenga un tema válido con el que arrancar.
  factory ThemeConfig.fallbackDefault({
    String id = 'default',
    int? seedArgb,
    bool oled = false,
  }) {
    final seed = seedArgb ?? kFolioBrandPrimaryArgb;
    return ThemeConfig(
      id: id,
      name: 'Folio',
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
