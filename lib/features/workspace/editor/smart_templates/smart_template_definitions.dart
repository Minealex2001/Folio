import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/block.dart';

/// Fase G2 del rediseño UX del editor — comandos multi-bloque con
/// variables (`/meeting`, `/sprint`, `/roadmap`). Cada comando inserta una
/// estructura pre-construida en vez de un bloque vacío, y — a diferencia
/// de una plantilla estática — puede pedir 1-2 variables mínimas antes de
/// generar (ej. `/meeting` → "¿Con quién?" → "¿Fecha?"), interpoladas en el
/// resultado final.
enum TemplateVariableType { text }

class TemplateVariable {
  const TemplateVariable({
    required this.id,
    required this.promptOf,
    this.type = TemplateVariableType.text,
  });

  final String id;

  /// Función en vez de String literal — el texto de la pregunta depende
  /// del locale activo, resuelto en el momento de mostrar el flujo.
  final String Function(AppLocalizations l10n) promptOf;
  final TemplateVariableType type;
}

/// [answers]: `variable.id` -> texto respondido (vacío si el usuario lo
/// dejó en blanco/omitió). `newBlockId`: genera un id único con el prefijo
/// de página correcto — el propio `SmartTemplateDefinition` no conoce el
/// `pageId`, lo recibe indirectamente a través de este generador.
typedef SmartTemplateBlockBuilder =
    List<FolioBlock> Function(
      Map<String, String> answers,
      String Function() newBlockId,
      AppLocalizations l10n,
    );

class SmartTemplateDefinition {
  const SmartTemplateDefinition({
    required this.key,
    required this.labelOf,
    required this.hintOf,
    required this.icon,
    this.variables = const [],
    required this.buildBlocks,
  });

  /// Clave `cmd_smart_*` — mismo espacio de nombres que los comandos `cmd_*`
  /// ya existentes (Fase G1), consolidado en el mismo catálogo de slash.
  final String key;
  final String Function(AppLocalizations l10n) labelOf;
  final String Function(AppLocalizations l10n) hintOf;
  final IconData icon;
  final List<TemplateVariable> variables;
  final SmartTemplateBlockBuilder buildBlocks;
}

final SmartTemplateDefinition kSmartTemplateMeeting = SmartTemplateDefinition(
  key: 'cmd_smart_meeting',
  labelOf: (l10n) => l10n.blockEditorCmdMeetingTemplate,
  hintOf: (l10n) => l10n.blockEditorCmdMeetingTemplateHint,
  icon: Icons.groups_outlined,
  variables: [
    TemplateVariable(id: 'attendee', promptOf: (l10n) => l10n.smartTemplateVariableMeetingWith),
    TemplateVariable(id: 'date', promptOf: (l10n) => l10n.smartTemplateVariableMeetingDate),
  ],
  buildBlocks: (answers, newBlockId, l10n) {
    final attendee = (answers['attendee'] ?? '').trim();
    final date = (answers['date'] ?? '').trim();
    return [
      FolioBlock(
        id: newBlockId(),
        type: 'h1',
        text: attendee.isEmpty
            ? l10n.smartTemplateMeetingDefaultTitle
            : l10n.smartTemplateMeetingTitleWith(attendee),
      ),
      if (date.isNotEmpty)
        FolioBlock(
          id: newBlockId(),
          type: 'callout',
          icon: '📅',
          text: l10n.smartTemplateMeetingDateLine(date),
        ),
      FolioBlock(id: newBlockId(), type: 'meeting_note', text: ''),
      FolioBlock(id: newBlockId(), type: 'toggle', text: l10n.smartTemplateMeetingAgenda),
      FolioBlock(id: newBlockId(), type: 'h2', text: l10n.smartTemplateMeetingActions),
      FolioBlock(id: newBlockId(), type: 'todo', text: ''),
    ];
  },
);

final SmartTemplateDefinition kSmartTemplateSprint = SmartTemplateDefinition(
  key: 'cmd_smart_sprint',
  labelOf: (l10n) => l10n.blockEditorCmdSprintTemplate,
  hintOf: (l10n) => l10n.blockEditorCmdSprintTemplateHint,
  icon: Icons.rocket_launch_outlined,
  variables: [
    TemplateVariable(id: 'name', promptOf: (l10n) => l10n.smartTemplateVariableSprintName),
  ],
  buildBlocks: (answers, newBlockId, l10n) {
    final name = (answers['name'] ?? '').trim();
    return [
      FolioBlock(
        id: newBlockId(),
        type: 'h1',
        text: name.isEmpty
            ? l10n.smartTemplateSprintDefaultTitle
            : l10n.smartTemplateSprintTitleWithName(name),
      ),
      FolioBlock(id: newBlockId(), type: 'h2', text: l10n.smartTemplateSprintGoals),
      FolioBlock(id: newBlockId(), type: 'bullet', text: ''),
      FolioBlock(id: newBlockId(), type: 'h2', text: l10n.smartTemplateSprintTasks),
      FolioBlock(id: newBlockId(), type: 'todo', text: ''),
    ];
  },
);

final SmartTemplateDefinition kSmartTemplateRoadmap = SmartTemplateDefinition(
  key: 'cmd_smart_roadmap',
  labelOf: (l10n) => l10n.blockEditorCmdRoadmapTemplate,
  hintOf: (l10n) => l10n.blockEditorCmdRoadmapTemplateHint,
  icon: Icons.map_outlined,
  // Sin variables — estructura fija, se inserta directamente sin pasar por
  // el mini-flujo de preguntas.
  buildBlocks: (answers, newBlockId, l10n) => [
    FolioBlock(id: newBlockId(), type: 'h1', text: l10n.smartTemplateRoadmapTitle),
    FolioBlock(id: newBlockId(), type: 'h2', text: l10n.smartTemplateRoadmapNow),
    FolioBlock(id: newBlockId(), type: 'bullet', text: ''),
    FolioBlock(id: newBlockId(), type: 'h2', text: l10n.smartTemplateRoadmapNext),
    FolioBlock(id: newBlockId(), type: 'bullet', text: ''),
    FolioBlock(id: newBlockId(), type: 'h2', text: l10n.smartTemplateRoadmapLater),
    FolioBlock(id: newBlockId(), type: 'bullet', text: ''),
  ],
);

const List<String> kSmartTemplateCmdKeys = [
  'cmd_smart_meeting',
  'cmd_smart_sprint',
  'cmd_smart_roadmap',
];

final List<SmartTemplateDefinition> kBuiltinSmartTemplates = [
  kSmartTemplateMeeting,
  kSmartTemplateSprint,
  kSmartTemplateRoadmap,
];

SmartTemplateDefinition? smartTemplateForCmdKey(String key) {
  for (final t in kBuiltinSmartTemplates) {
    if (t.key == key) return t;
  }
  return null;
}
