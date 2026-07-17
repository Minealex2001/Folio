import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Fila de estado mostrada mientras el bucle de tool-calling de Quill
/// (`ai_tool_loop.dart`) está ejecutando una acción concreta — p. ej. "Quill
/// está creando la página 'Notas del viaje'…" — en vez del shimmer genérico
/// de [FolioAiChatReplySkeleton] cuando no hay nada más específico que decir.
class AiToolActivityIndicator extends StatelessWidget {
  const AiToolActivityIndicator({
    super.key,
    required this.label,
    required this.colorScheme,
  });

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip de error para una tool-call fallida durante un turno del agente,
/// mostrado bajo la burbuja de respuesta y visualmente distinto de la
/// respuesta en texto normal (`AiChatMessage.toolErrors`).
class AiToolErrorChip extends StatelessWidget {
  const AiToolErrorChip({
    super.key,
    required this.message,
    required this.colorScheme,
  });

  final String message;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(FolioRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Traduce el nombre técnico de una tool a una etiqueta legible para
/// [AiToolActivityIndicator]. Desconocida cae a una etiqueta genérica.
String aiToolActivityLabel({
  required String toolName,
  required AppLocalizations l10n,
}) {
  switch (toolName) {
    case 'create_page':
      return l10n.aiToolActivityCreatePage;
    case 'create_folder':
      return l10n.aiToolActivityCreateFolder;
    case 'append_blocks_to_page':
      return l10n.aiToolActivityAppendBlocks;
    case 'replace_page_blocks':
      return l10n.aiToolActivityReplaceBlocks;
    case 'edit_page_blocks':
      return l10n.aiToolActivityEditBlocks;
    case 'insert_blocks_at_position':
      return l10n.aiToolActivityInsertBlocks;
    case 'insert_todos':
      return l10n.aiToolActivityInsertTodos;
    case 'insert_tasks':
      return l10n.aiToolActivityInsertTasks;
    case 'translate_page_bilingual':
      return l10n.aiToolActivityTranslate;
    case 'rename_page':
      return l10n.aiToolActivityRenamePage;
    case 'move_page':
      return l10n.aiToolActivityMovePage;
    case 'reorder_page':
      return l10n.aiToolActivityReorderPage;
    case 'duplicate_page':
      return l10n.aiToolActivityDuplicatePage;
    case 'set_page_emoji':
      return l10n.aiToolActivitySetEmoji;
    case 'add_page_tag':
      return l10n.aiToolActivityAddTag;
    case 'remove_page_tag':
      return l10n.aiToolActivityRemoveTag;
    case 'trash_page':
      return l10n.aiToolActivityTrashPage;
    case 'restore_page':
      return l10n.aiToolActivityRestorePage;
    case 'permanently_delete_page':
      return l10n.aiToolActivityDeletePage;
    case 'empty_trash':
      return l10n.aiToolActivityEmptyTrash;
    case 'delete_folder_flatten_children':
      return l10n.aiToolActivityDeleteFolder;
    case 'search_pages':
      return l10n.aiToolActivitySearchPages;
    case 'list_children':
      return l10n.aiToolActivityListChildren;
    default:
      return l10n.aiToolActivityWorking;
  }
}
