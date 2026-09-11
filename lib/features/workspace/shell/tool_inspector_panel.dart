import 'package:flutter/material.dart';

/// Fase A6 del plan Quill/MCP — traza en vivo de la ejecución de Quill,
/// tipo Cursor: antes de esta fase, `AiToolActivityIndicator` (ver
/// `ai_tool_activity_indicator.dart`) solo mostraba la etiqueta de la tool
/// EN CURSO — cada nueva tool-call sobrescribía la anterior, así que el
/// usuario nunca veía la secuencia completa de un turno con varios pasos
/// (`Plan → Search ✔ → Read ✔ → Create Page ✔`), solo el paso actual.
/// `ToolInspectorPanel` acumula todos los pasos del turno en curso.
enum ToolInspectorStepStatus { running, success, error }

class ToolInspectorStep {
  const ToolInspectorStep({required this.label, required this.status});

  final String label;
  final ToolInspectorStepStatus status;

  ToolInspectorStep copyWith({ToolInspectorStepStatus? status}) =>
      ToolInspectorStep(label: label, status: status ?? this.status);
}

class ToolInspectorPanel extends StatelessWidget {
  const ToolInspectorPanel({
    super.key,
    required this.steps,
    required this.colorScheme,
  });

  final List<ToolInspectorStep> steps;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps) _stepRow(step),
      ],
    );
  }

  Widget _stepRow(ToolInspectorStep step) {
    Widget icon;
    switch (step.status) {
      case ToolInspectorStepStatus.running:
        icon = SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        );
      case ToolInspectorStepStatus.success:
        icon = Icon(Icons.check_circle_rounded, size: 14, color: colorScheme.tertiary);
      case ToolInspectorStepStatus.error:
        icon = Icon(Icons.cancel_rounded, size: 14, color: colorScheme.error);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 14, height: 14, child: Center(child: icon)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              step.label,
              style: TextStyle(
                color: step.status == ToolInspectorStepStatus.running
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                fontStyle: step.status == ToolInspectorStepStatus.running
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
