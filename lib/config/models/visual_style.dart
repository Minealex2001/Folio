import 'package:json_annotation/json_annotation.dart';

import 'token_ref.dart';

part 'visual_style.g.dart';

/// Densidad/glass/bordes/ventana/cursor/iconografía consolidados en un solo
/// modelo (Fase 20) — el borrador original tenía 5 clases separadas
/// (`ThemeDensityTokens`/`ThemeGlassTokens`/`ThemeBorderTokens`/
/// `ThemeWindowStyleTokens`/`ThemeCursorTokens`); el usuario pidió agrupar
/// ("yo intentaría agrupar... reduciría muchísimo el ruido"), así que este
/// único modelo reemplaza los 5. Un solo punto de entrada en [ThemeConfig],
/// un solo resolver (`visual_style_resolver.dart`).
@JsonSerializable(explicitToJson: true)
class VisualStyle {
  const VisualStyle({
    this.densityMode = 'compact',
    this.densityScale = 1.0,
    this.glassSidebarOpacity,
    this.glassDialogOpacity,
    this.glassMenuOpacity,
    this.glassPanelOpacity,
    this.borderEnabled = false,
    this.borderWidth,
    this.borderOpacity,
    this.windowTitleBar = 'native',
    this.windowCorners,
    this.windowBackdrop = 'none',
    this.cursorHover = 'basic',
    this.cursorResize = 'resizeColumn',
    this.cursorText = 'text',
    this.iconStyle,
    this.iconSize,
    this.iconStrokeWidth,
  });

  /// 'compact' | 'comfortable' | 'spacious'.
  final String densityMode;
  final double densityScale;

  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? glassSidebarOpacity;
  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? glassDialogOpacity;
  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? glassMenuOpacity;
  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? glassPanelOpacity;

  final bool borderEnabled;
  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? borderWidth;
  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? borderOpacity;

  /// 'native' | 'custom' | 'hidden'.
  final String windowTitleBar;

  /// 'system' | 'rounded' | 'square'; null = 'system'.
  final String? windowCorners;

  /// 'none' | 'blur' — 'mica'/'acrylic' reservados, degradan a 'blur' (no
  /// hay dependencia `flutter_acrylic` en el repo).
  final String windowBackdrop;

  /// Nombres mapeados a `SystemMouseCursors` por `cursor_resolver` en
  /// `visual_style_resolver.dart`, con fallback de nombre desconocido.
  final String cursorHover;
  final String cursorResize;
  final String cursorText;

  /// 'filled' | 'outlined' | 'rounded'; null = default del icon pack activo.
  final String? iconStyle;
  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? iconSize;
  final double? iconStrokeWidth;

  factory VisualStyle.fromJson(Map<String, dynamic> json) =>
      _$VisualStyleFromJson(json);

  Map<String, dynamic> toJson() => _$VisualStyleToJson(this);
}
