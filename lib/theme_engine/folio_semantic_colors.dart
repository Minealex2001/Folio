import 'package:flutter/material.dart';

/// Roles de color semántico resueltos (Fase 14) — expuesto como
/// `ThemeExtension` (el mecanismo idiomático de Flutter para datos
/// adyacentes al tema que no encajan en `ColorScheme`), leído vía
/// `Theme.of(context).extension<FolioSemanticColors>()!`.
@immutable
class FolioSemanticColors extends ThemeExtension<FolioSemanticColors> {
  const FolioSemanticColors({
    required this.editorBackground,
    required this.sidebarBackground,
    required this.sidebarHover,
    required this.sidebarSelection,
    required this.cardBackground,
    required this.panelBackground,
    required this.toolbarBackground,
    required this.windowBackground,
    required this.canvasBackground,
    required this.selection,
    required this.hover,
    required this.focus,
    required this.warning,
    required this.success,
    required this.info,
  });

  final Color editorBackground;
  final Color sidebarBackground;
  final Color sidebarHover;
  final Color sidebarSelection;
  final Color cardBackground;
  final Color panelBackground;
  final Color toolbarBackground;
  final Color windowBackground;
  final Color canvasBackground;
  final Color selection;
  final Color hover;
  final Color focus;
  final Color warning;
  final Color success;
  final Color info;

  @override
  FolioSemanticColors copyWith({
    Color? editorBackground,
    Color? sidebarBackground,
    Color? sidebarHover,
    Color? sidebarSelection,
    Color? cardBackground,
    Color? panelBackground,
    Color? toolbarBackground,
    Color? windowBackground,
    Color? canvasBackground,
    Color? selection,
    Color? hover,
    Color? focus,
    Color? warning,
    Color? success,
    Color? info,
  }) {
    return FolioSemanticColors(
      editorBackground: editorBackground ?? this.editorBackground,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      sidebarHover: sidebarHover ?? this.sidebarHover,
      sidebarSelection: sidebarSelection ?? this.sidebarSelection,
      cardBackground: cardBackground ?? this.cardBackground,
      panelBackground: panelBackground ?? this.panelBackground,
      toolbarBackground: toolbarBackground ?? this.toolbarBackground,
      windowBackground: windowBackground ?? this.windowBackground,
      canvasBackground: canvasBackground ?? this.canvasBackground,
      selection: selection ?? this.selection,
      hover: hover ?? this.hover,
      focus: focus ?? this.focus,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      info: info ?? this.info,
    );
  }

  @override
  FolioSemanticColors lerp(ThemeExtension<FolioSemanticColors>? other, double t) {
    if (other is! FolioSemanticColors) return this;
    return FolioSemanticColors(
      editorBackground: Color.lerp(editorBackground, other.editorBackground, t)!,
      sidebarBackground: Color.lerp(sidebarBackground, other.sidebarBackground, t)!,
      sidebarHover: Color.lerp(sidebarHover, other.sidebarHover, t)!,
      sidebarSelection: Color.lerp(sidebarSelection, other.sidebarSelection, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
      toolbarBackground: Color.lerp(toolbarBackground, other.toolbarBackground, t)!,
      windowBackground: Color.lerp(windowBackground, other.windowBackground, t)!,
      canvasBackground: Color.lerp(canvasBackground, other.canvasBackground, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}
