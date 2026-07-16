import 'package:flutter/material.dart';

import '../../../app/ui_tokens.dart';

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
/// [AiToolActivityIndicator]. `null`/desconocida cae a una etiqueta genérica.
String aiToolActivityLabel({
  required String toolName,
  required bool isEs,
}) {
  const labelsEs = {
    'create_page': 'Quill está creando una página…',
    'create_folder': 'Quill está creando una carpeta…',
    'append_blocks_to_page': 'Quill está añadiendo contenido…',
    'replace_page_blocks': 'Quill está reescribiendo la página…',
    'edit_page_blocks': 'Quill está editando bloques…',
    'insert_blocks_at_position': 'Quill está insertando contenido…',
    'insert_todos': 'Quill está añadiendo tareas…',
    'insert_tasks': 'Quill está añadiendo tareas…',
    'translate_page_bilingual': 'Quill está traduciendo…',
    'rename_page': 'Quill está renombrando la página…',
    'move_page': 'Quill está moviendo la página…',
    'reorder_page': 'Quill está reordenando la página…',
    'duplicate_page': 'Quill está duplicando la página…',
    'set_page_emoji': 'Quill está cambiando el icono…',
    'add_page_tag': 'Quill está añadiendo una etiqueta…',
    'remove_page_tag': 'Quill está quitando una etiqueta…',
    'trash_page': 'Quill está moviendo la página a la papelera…',
    'restore_page': 'Quill está restaurando la página…',
    'permanently_delete_page': 'Quill está borrando la página…',
    'empty_trash': 'Quill está vaciando la papelera…',
    'delete_folder_flatten_children': 'Quill está borrando la carpeta…',
    'search_pages': 'Quill está buscando en tu libreta…',
    'list_children': 'Quill está explorando tus páginas…',
  };
  const labelsEn = {
    'create_page': 'Quill is creating a page…',
    'create_folder': 'Quill is creating a folder…',
    'append_blocks_to_page': 'Quill is adding content…',
    'replace_page_blocks': 'Quill is rewriting the page…',
    'edit_page_blocks': 'Quill is editing blocks…',
    'insert_blocks_at_position': 'Quill is inserting content…',
    'insert_todos': 'Quill is adding to-dos…',
    'insert_tasks': 'Quill is adding tasks…',
    'translate_page_bilingual': 'Quill is translating…',
    'rename_page': 'Quill is renaming the page…',
    'move_page': 'Quill is moving the page…',
    'reorder_page': 'Quill is reordering the page…',
    'duplicate_page': 'Quill is duplicating the page…',
    'set_page_emoji': 'Quill is changing the icon…',
    'add_page_tag': 'Quill is adding a tag…',
    'remove_page_tag': 'Quill is removing a tag…',
    'trash_page': 'Quill is moving the page to trash…',
    'restore_page': 'Quill is restoring the page…',
    'permanently_delete_page': 'Quill is deleting the page…',
    'empty_trash': 'Quill is emptying the trash…',
    'delete_folder_flatten_children': 'Quill is deleting the folder…',
    'search_pages': 'Quill is searching your notebook…',
    'list_children': 'Quill is browsing your pages…',
  };
  final table = isEs ? labelsEs : labelsEn;
  return table[toolName] ?? (isEs ? 'Quill está trabajando…' : 'Quill is working…');
}
