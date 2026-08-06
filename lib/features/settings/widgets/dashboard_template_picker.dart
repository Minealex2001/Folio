import 'package:flutter/material.dart';

import '../../../dashboard_templates/builtin_dashboard_templates.dart';
import '../../../widget_catalog/dnd/dashboard_grid_controller.dart';

/// Selector de plantillas de dashboard (Fase 30, punto 5 del brief) —
/// Developer/Writer/Research/Student/Planning/Gaming, intercambiables.
/// El soporte de storage (`loadDashboard(id)`/`switchToTemplate`) ya
/// existe; este widget es la UI que lo expone.
class DashboardTemplatePicker extends StatelessWidget {
  const DashboardTemplatePicker({super.key, required this.controller});

  final DashboardGridController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final activeId = controller.config.id;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in kBuiltinDashboardTemplates)
              ChoiceChip(
                label: Text(entry.displayName),
                selected: entry.id == activeId,
                onSelected: (_) =>
                    controller.switchToTemplate(entry.id, entry.build()),
              ),
          ],
        );
      },
    );
  }
}
