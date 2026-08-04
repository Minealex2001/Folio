/// IDs canónicos de región de panel, compartidos entre los modelos de
/// configuración (esta capa) y el motor de layout (`lib/layout_engine/`,
/// Fase 2). Viven aquí — no en `layout_engine/` — para que los modelos de
/// `LayoutConfig.defaultConfig()` no dependan de la capa de widgets.
abstract final class PanelRegionIds {
  static const String sidebarLeft = 'sidebarLeft';
  static const String sidebarRight = 'sidebarRight';
  static const String main = 'main';
  static const String floatingAi = 'floatingAi';
  static const String floatingCollab = 'floatingCollab';
  static const String floatingInspector = 'floatingInspector'; // Fase 6
}
