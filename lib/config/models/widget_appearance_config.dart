import 'package:json_annotation/json_annotation.dart';

part 'widget_appearance_config.g.dart';

/// Configuración visual genérica por-INSTANCIA (Fase 31) — color/opacidad/
/// borde/sombra/radio, misma forma para cualquier widget. Distinto de
/// `WidgetThemeTokens` (Fase 23, tema semántico por-TIPO de widget) y
/// separado deliberadamente del mapa opaco `WidgetInstanceConfig.settings`
/// (privado-del-plugin) — esto lo posee el motor, no el plugin.
///
/// Migra las 3 claves que el editor visual ya escribía en `settings`
/// (`colorOverrideArgb`/`opacityOverride`/`cornerRadiusOverride`) a un campo
/// tipado, manteniendo esas claves legibles como fallback para instancias
/// ya guardadas — ver `WidgetInstanceFrame._applyOverrides` y
/// `WidgetInstanceSelectable`.
@JsonSerializable()
class WidgetAppearanceConfig {
  const WidgetAppearanceConfig({
    this.backgroundColorArgb,
    this.opacity,
    this.border,
    this.shadow,
    this.cornerRadius,
  });

  final int? backgroundColorArgb;
  final double? opacity;
  final bool? border;
  final bool? shadow;
  final double? cornerRadius;

  factory WidgetAppearanceConfig.fromJson(Map<String, dynamic> json) =>
      _$WidgetAppearanceConfigFromJson(json);

  Map<String, dynamic> toJson() => _$WidgetAppearanceConfigToJson(this);

  WidgetAppearanceConfig copyWith({
    int? backgroundColorArgb,
    bool clearBackgroundColorArgb = false,
    double? opacity,
    bool clearOpacity = false,
    bool? border,
    bool? shadow,
    double? cornerRadius,
    bool clearCornerRadius = false,
  }) {
    return WidgetAppearanceConfig(
      backgroundColorArgb: clearBackgroundColorArgb
          ? null
          : (backgroundColorArgb ?? this.backgroundColorArgb),
      opacity: clearOpacity ? null : (opacity ?? this.opacity),
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      cornerRadius: clearCornerRadius ? null : (cornerRadius ?? this.cornerRadius),
    );
  }
}
