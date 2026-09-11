/// Qué tipo de elemento representa un [Selectable].
enum SelectableKind { panel, widgetInstance }

/// Adaptador de selección del editor visual (Fase 6) sobre un elemento
/// editable — un panel del motor de layout ([PanelSelectable], Fase 2) o
/// una instancia de widget del dashboard ([WidgetInstanceSelectable],
/// Fase 5). El inspector de propiedades solo conoce esta interfaz, nunca el
/// tipo concreto — así un futuro tercer tipo de elemento seleccionable no
/// requiere tocar el inspector.
///
/// Los paneles no tienen concepto de color/opacidad/radio hoy — sus
/// getters devuelven null y los setters son no-op para
/// [PanelSelectable]. El inspector oculta esas secciones cuando el valor
/// es null en vez de necesitar un `is WidgetInstanceSelectable`.
abstract class Selectable {
  SelectableKind get kind;

  /// Id estable del elemento (region id de panel, o instance id de widget).
  String get id;

  double? get width;
  double? get height;

  /// Posición cuando el elemento flota libremente; null si está anclado o
  /// el tipo de elemento no soporta posición libre (ej. instancias de
  /// dashboard en v1, que siguen el flujo de columnas — ver Fase 5).
  double? get x;
  double? get y;

  bool get locked;

  int? get colorArgb;
  double? get opacity;
  double? get cornerRadius;

  void setSize({double? width, double? height});
  void setPosition({double? x, double? y});
  void setColorArgb(int? argb);
  void setOpacity(double? opacity);
  void setCornerRadius(double? radius);
}
