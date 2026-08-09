import 'package:flutter/material.dart';

/// Fase A2 del plan Quill/MCP — componente genérico de "aquí hay un
/// resultado, elige qué hacer con él", reutilizable desde cualquier
/// superficie de IA (chat, popover D1, slash intents) sin reimplementar la
/// lógica de aplicar cambios en cada una.
///
/// Se llama "Intent Actions" y no "AI Output Actions" a propósito: el
/// payload accionable no tiene por qué originarse siempre en una respuesta
/// de IA — mañana puede venir de un plugin, una llamada MCP externa, o un
/// Workflow. Este widget no sabe nada de eso; solo pinta la fila de botones
/// que el llamador decide construir, con el estilo visual ya establecido
/// (el botón principal en `FilledButton.tonal`, los secundarios en
/// `OutlinedButton` — mismo lenguaje que ya usaban los 3 botones originales
/// de aplicar-snapshot del chat).
enum IntentActionKind { blocks, operations, plainText }

/// De dónde vino la propuesta — informativo hoy (solo `ai` se emite), pero
/// deja sitio para que futuras superficies (plugin/mcp/workflow) reutilicen
/// exactamente el mismo componente sin rediseñarlo.
enum IntentActionSource { ai, plugin, mcp, workflow }

/// Metadata pura de "qué se propone aplicar" — no ejecuta nada por sí sola.
class IntentActionProposal {
  const IntentActionProposal({
    required this.kind,
    this.source = IntentActionSource.ai,
    this.blocks,
    this.operations,
    this.text,
    this.sourcePageId,
    this.sourceBlockId,
  });

  final IntentActionKind kind;
  final IntentActionSource source;
  final List<Map<String, dynamic>>? blocks;
  final List<Map<String, dynamic>>? operations;
  final String? text;
  final String? sourcePageId;
  final String? sourceBlockId;
}

/// Un botón de la barra — el llamador decide label/icono/acción; este
/// archivo no conoce `VaultSession` ni ningún tipo de aplicar-cambios
/// concreto, así que no puede reimplementar ninguna ejecución.
class IntentAction {
  const IntentAction({
    required this.id,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
  });

  final String id;
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  /// Como mucho un botón por barra debería ser `primary` (se pinta
  /// `FilledButton.tonal`); el resto son `OutlinedButton`.
  final bool primary;
}

class IntentActionBar extends StatelessWidget {
  const IntentActionBar({super.key, required this.actions});

  final List<IntentAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          action.primary
              ? FilledButton.tonal(
                  onPressed: action.onPressed,
                  child: _actionLabel(action),
                )
              : OutlinedButton(
                  onPressed: action.onPressed,
                  child: _actionLabel(action),
                ),
      ],
    );
  }

  Widget _actionLabel(IntentAction action) {
    if (action.icon == null) return Text(action.label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(action.icon, size: 16),
        const SizedBox(width: 6),
        Text(action.label),
      ],
    );
  }
}
