import 'package:flutter/foundation.dart';

import 'selectable.dart';

/// Estado del modo edición visual (Fase 6): si está activo, y qué
/// [Selectable] está seleccionado. Las escrituras hacia
/// `LayoutConfig`/`WidgetInstanceConfig` son inmediatas en memoria (feedback
/// instantáneo) y debounced a disco — eso ya lo maneja cada controller
/// (`LayoutEngineController`/`DashboardGridController`) subyacente; este
/// controller solo coordina qué está seleccionado y si el modo está activo.
///
/// Sin undo granular por propiedad en v1 — [revertSelection] (recarga desde
/// `ConfigStore`, descartando ediciones no persistidas del elemento
/// seleccionado) es la red de seguridad, no un historial completo.
class VisualEditorController extends ChangeNotifier {
  bool _editModeActive = false;
  Selectable? _selected;

  bool get editModeActive => _editModeActive;
  Selectable? get selected => _selected;

  set editModeActive(bool value) {
    if (_editModeActive == value) return;
    _editModeActive = value;
    if (!value) _selected = null;
    notifyListeners();
  }

  void select(Selectable selectable) {
    _selected = selectable;
    notifyListeners();
  }

  void clearSelection() {
    if (_selected == null) return;
    _selected = null;
    notifyListeners();
  }

  /// True si [selectable] es el elemento actualmente seleccionado (mismo
  /// [SelectableKind] + id) — usado por `SelectableTapWrapper` para pintar
  /// el outline sin tener que comparar instancias por identidad.
  bool isSelected(SelectableKind kind, String id) {
    final current = _selected;
    return current != null && current.kind == kind && current.id == id;
  }
}
