import 'package:json_annotation/json_annotation.dart';

import 'token_ref.dart';

part 'editor_layout_tokens.g.dart';

/// Tokens estructurales del editor de bloques (Fase 27, anexo del brief) —
/// altura de línea/espaciado entre bloques, ancho/parpadeo de cursor, color/
/// radio/animación de selección, visibilidad de símbolos markdown, preset
/// de estilo de callout.
///
/// Deliberadamente NO incluye `maxWidth` — eso es
/// `AppSettings.editorContentWidth`, que sigue siendo la fuente de verdad
/// (ver nota en el plan); consolidarlos es un seguimiento futuro, no parte
/// de esta fase, para no tocar un getter muy referenciado a mitad de plan.
@JsonSerializable(explicitToJson: true)
class EditorLayoutTokens {
  const EditorLayoutTokens({
    this.lineHeightScale = 1.0,
    this.blockSpacing,
    this.cursorWidth = 2.0,
    this.cursorBlink = true,
    this.selectionColor,
    this.selectionRadius,
    this.selectionAnimated = true,
    this.markdownSymbolVisibility = 'editingOnly',
    this.calloutStyle = 'notion',
  });

  final double lineHeightScale;

  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? blockSpacing;

  final double cursorWidth;
  final bool cursorBlink;

  @NullableTokenRefIntConverter()
  final TokenRef<int>? selectionColor;
  @NullableTokenRefDoubleConverter()
  final TokenRef<double>? selectionRadius;
  final bool selectionAnimated;

  /// 'always' | 'never' | 'editingOnly'.
  final String markdownSymbolVisibility;

  /// 'notion' | 'obsidian' | 'minimal' — ver `callout_style_presets.dart`.
  final String calloutStyle;

  factory EditorLayoutTokens.fromJson(Map<String, dynamic> json) =>
      _$EditorLayoutTokensFromJson(json);

  Map<String, dynamic> toJson() => _$EditorLayoutTokensToJson(this);
}
