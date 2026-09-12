import 'package:json_annotation/json_annotation.dart';

import 'token_ref.dart';

part 'semantic_color_tokens.g.dart';

/// Roles de color con nombre más allá del `ColorScheme` de Material (Fase
/// 14, punto 3 del brief): superficies concretas de la UI de Folio
/// (sidebar, toolbar, editor…) y estados semánticos (warning/success/info)
/// que Material no modela de fábrica.
///
/// Cada campo es `TokenRef<int>?` — `null` significa "derivar del
/// `ColorScheme` resuelto como hoy" (ver los defaults campo a campo
/// documentados en `semantic_colors_resolver.dart`); un valor no-null
/// (literal o referencia `@color.xxx`) gana. No está partido por brillo: se
/// resuelve contra el `ColorScheme` ya resuelto para el brillo activo, así
/// que el mismo `SemanticColorTokens` sirve para claro y oscuro.
@JsonSerializable(explicitToJson: true)
class SemanticColorTokens {
  const SemanticColorTokens({
    this.editorBackground,
    this.sidebarBackground,
    this.sidebarHover,
    this.sidebarSelection,
    this.cardBackground,
    this.panelBackground,
    this.toolbarBackground,
    this.windowBackground,
    this.canvasBackground,
    this.selection,
    this.hover,
    this.focus,
    this.warning,
    this.success,
    this.info,
  });

  @NullableTokenRefIntConverter()
  final TokenRef<int>? editorBackground;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? sidebarBackground;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? sidebarHover;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? sidebarSelection;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? cardBackground;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? panelBackground;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? toolbarBackground;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? windowBackground;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? canvasBackground;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? selection;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? hover;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? focus;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? warning;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? success;
  @NullableTokenRefIntConverter()
  final TokenRef<int>? info;

  factory SemanticColorTokens.fromJson(Map<String, dynamic> json) =>
      _$SemanticColorTokensFromJson(json);

  Map<String, dynamic> toJson() => _$SemanticColorTokensToJson(this);
}
