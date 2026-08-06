import 'package:json_annotation/json_annotation.dart';

import '../json_schema_version.dart';
import 'editor_layout_tokens.dart';
import 'panel_config.dart';
import 'panel_region_ids.dart';
import 'toolbar_config.dart';

part 'layout_config.g.dart';

/// Valores por defecto de los anchos de panel, tomados literalmente de las
/// constantes actuales en `lib/app/ui_tokens.dart` (`FolioDesktop`) para que
/// el `LayoutConfig` por defecto reproduzca el layout de hoy sin regresión.
abstract final class LayoutConfigDefaults {
  static const double sidebarWidth = 280;
  static const double aiPanelWidth = 360;
  static const double aiPanelHeight = 480;
}

/// Configuración de layout: qué paneles existen, si están visibles,
/// su tamaño/posición y si están bloqueados. No contiene nada de tema
/// (colores, tipografía) — separación estricta layout/tema del brief.
@JsonSerializable(explicitToJson: true)
class LayoutConfig {
  LayoutConfig({
    this.schemaVersion = kFolioConfigSchemaVersion,
    required this.id,
    required this.name,
    required this.panels,
    this.responsiveOverrides,
    this.toolbar,
    this.editor,
  });

  final int schemaVersion;

  /// 'default', o el id de un preset guardado por el usuario.
  final String id;
  final String name;

  /// Key = [PanelRegionIds].
  final Map<String, PanelConfig> panels;

  /// Overrides parciales por breakpoint (Fase 7). Key = `Breakpoint.name`
  /// ('mobile'/'tablet'/'desktop'/'ultrawide'). Solo se listan los paneles
  /// que difieren de la config base — se fusionan en tiempo de resolución,
  /// no se duplica el árbol completo por breakpoint.
  final Map<String, LayoutConfig>? responsiveOverrides;

  /// Posición/visibilidad de la toolbar (Fase 25). `null` = `AppBar` fija
  /// de hoy, sin cambios.
  final ToolbarConfig? toolbar;

  /// Tokens estructurales del editor (Fase 27). `null` = literales de hoy.
  final EditorLayoutTokens? editor;

  factory LayoutConfig.fromJson(Map<String, dynamic> json) =>
      _$LayoutConfigFromJson(json);

  Map<String, dynamic> toJson() => _$LayoutConfigToJson(this);

  LayoutConfig copyWith({
    String? name,
    Map<String, PanelConfig>? panels,
    Map<String, LayoutConfig>? responsiveOverrides,
    ToolbarConfig? toolbar,
    EditorLayoutTokens? editor,
  }) {
    return LayoutConfig(
      schemaVersion: schemaVersion,
      id: id,
      name: name ?? this.name,
      panels: panels ?? this.panels,
      responsiveOverrides: responsiveOverrides ?? this.responsiveOverrides,
      toolbar: toolbar ?? this.toolbar,
      editor: editor ?? this.editor,
    );
  }

  /// Layout por defecto: reproduce el shell hardcodeado de hoy
  /// (`workspace_shell.dart`) — sidebar izquierdo visible, panel de IA y de
  /// colaboración flotantes ocultos por defecto.
  factory LayoutConfig.defaultConfig({String id = 'default'}) {
    return LayoutConfig(
      id: id,
      name: 'Default',
      panels: {
        PanelRegionIds.sidebarLeft: PanelConfig(
          regionId: PanelRegionIds.sidebarLeft,
          visible: true,
          width: LayoutConfigDefaults.sidebarWidth,
        ),
        PanelRegionIds.main: PanelConfig(
          regionId: PanelRegionIds.main,
          visible: true,
        ),
        PanelRegionIds.floatingAi: PanelConfig(
          regionId: PanelRegionIds.floatingAi,
          visible: false,
          width: LayoutConfigDefaults.aiPanelWidth,
          height: LayoutConfigDefaults.aiPanelHeight,
        ),
        PanelRegionIds.floatingCollab: PanelConfig(
          regionId: PanelRegionIds.floatingCollab,
          visible: false,
        ),
      },
    );
  }
}
