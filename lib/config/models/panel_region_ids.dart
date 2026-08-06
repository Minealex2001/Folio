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

  /// Bandas horizontales encima/debajo de la composición ancla/flotante
  /// principal (Fase 24) — para una toolbar acoplada arriba/abajo (Fase 25)
  /// o una tira de pestañas (Fase 29). Usan `PanelConfig.height`, no
  /// `.width`, ya que ocupan todo el ancho disponible.
  static const String toolbarTop = 'toolbarTop';
  static const String toolbarBottom = 'toolbarBottom';
}
