import 'package:flutter/material.dart';

import 'selectable.dart';
import 'visual_editor_controller.dart';

/// Envuelve [child] con selección por tap cuando el editor visual está
/// activo — se monta en `PanelFrame`/`WidgetInstanceFrame`. Cuando
/// [VisualEditorController.editModeActive] es false, es un passthrough
/// puro (ni `GestureDetector` ni `AnimatedBuilder` de por medio) — cero
/// costo cuando el modo está apagado, no solo "oculto".
class SelectableTapWrapper extends StatelessWidget {
  const SelectableTapWrapper({
    super.key,
    required this.controller,
    required this.selectable,
    required this.child,
  });

  final VisualEditorController controller;
  final Selectable selectable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!controller.editModeActive) return child;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isSelected = controller.isSelected(
          selectable.kind,
          selectable.id,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.select(selectable),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
