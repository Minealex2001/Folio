/// Qué puede hacer el usuario con una instancia de widget colocada — el
/// escape hatch estructurado para el punto 10 del brief ("capacidades de
/// widget"), en vez de que `WidgetInstanceFrame` asuma incondicionalmente
/// que todo widget es movible/redimensionable/duplicable/cerrable.
///
/// Declarado por el plugin (`FolioWidgetPlugin.capabilities`) como el
/// default para ese tipo de widget, y opcionalmente afinado por instancia
/// vía [WidgetCapabilityOverrides] — mismo patrón de fallback de dos niveles
/// que el resto del sistema de personalización.
class WidgetCapabilities {
  const WidgetCapabilities({
    this.movable = true,
    this.resizable = true,
    this.duplicable = true,
    this.closable = true,
    this.detachable = false,
  });

  final bool movable;
  final bool resizable;
  final bool duplicable;
  final bool closable;

  /// Reservado para cuando un widget pueda "desacoplarse" a una ventana o
  /// panel flotante propio — no consumido todavía por ningún renderer.
  final bool detachable;
}
