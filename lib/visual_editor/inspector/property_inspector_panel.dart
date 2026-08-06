import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../selectable.dart';
import '../visual_editor_controller.dart';
import 'color_opacity_editor.dart';
import 'corner_radius_editor.dart';
import 'size_position_editor.dart';

/// Panel flotante del editor visual (Fase 6) — deliberadamente un widget
/// más, pensado para alojarse como región `PanelRegionIds.floatingInspector`
/// dentro de un `PanelHost` (Fase 2): el editor no tiene implementación de
/// panel flotante propia, reutiliza la general — ver
/// `property_inspector_panel_test.dart` para la prueba de que efectivamente
/// puede montarse dentro de un `PanelHost` real.
///
/// [repaintOn] es opcional: además de [controller] (cambios de selección),
/// el inspector debe reconstruirse cuando cambian los datos del elemento
/// seleccionado (ej. otro gesto de resize) — pásale el
/// `LayoutEngineController`/`DashboardGridController` subyacente si el
/// caller no envuelve ya el árbol en algo que escuche esos cambios.
class PropertyInspectorPanel extends StatelessWidget {
  const PropertyInspectorPanel({
    super.key,
    required this.controller,
    this.repaintOn,
  });

  final VisualEditorController controller;
  final Listenable? repaintOn;

  @override
  Widget build(BuildContext context) {
    final animation = repaintOn == null
        ? controller
        : Listenable.merge([controller, repaintOn]);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final selected = controller.selected;
        if (selected == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(AppLocalizations.of(context).inspectorSelectElement),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SizePositionEditor(selectable: selected),
            if (selected.kind == SelectableKind.widgetInstance) ...[
              const Divider(height: 24),
              ColorOpacityEditor(selectable: selected),
              const Divider(height: 24),
              CornerRadiusEditor(selectable: selected),
            ],
          ],
        );
      },
    );
  }
}
