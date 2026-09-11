import 'package:json_annotation/json_annotation.dart';

part 'toolbar_config.g.dart';

/// Posición/visibilidad/flotación de la toolbar (Fase 25, anexo del brief).
/// `null` en [LayoutConfig.toolbar] = la `AppBar` fija de 64px de hoy
/// (`WorkspaceTopAppBar`), sin cambios — este modelo declara la intención,
/// la reubicación real de la toolbar hacia una banda de `PanelHost`/
/// `WorkspaceBodyShellV2` (Fase 24) queda como trabajo de UI de seguimiento,
/// no ejecutada en esta fase.
@JsonSerializable()
class ToolbarConfig {
  const ToolbarConfig({
    this.visible = true,
    this.position = 'top',
    this.floatingX,
    this.floatingY,
    this.height = 64,
  });

  final bool visible;

  /// 'top' | 'bottom' | 'floating'.
  final String position;

  final double? floatingX;
  final double? floatingY;
  final double height;

  factory ToolbarConfig.fromJson(Map<String, dynamic> json) =>
      _$ToolbarConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ToolbarConfigToJson(this);

  ToolbarConfig copyWith({
    bool? visible,
    String? position,
    double? floatingX,
    double? floatingY,
    double? height,
  }) {
    return ToolbarConfig(
      visible: visible ?? this.visible,
      position: position ?? this.position,
      floatingX: floatingX ?? this.floatingX,
      floatingY: floatingY ?? this.floatingY,
      height: height ?? this.height,
    );
  }
}
