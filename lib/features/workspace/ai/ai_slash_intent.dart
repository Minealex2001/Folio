/// Intención disparada desde el menú slash `/` de Quill en el editor.
enum AiSlashIntent {
  summarize,
  continueWriting,
  explain,
  actionItems,
  todo,
  mindmap,
  table,
  improve,
  translate,
}

/// Parámetros que el editor envía al espacio de trabajo para ejecutar Quill.
class FolioAiSlashParams {
  const FolioAiSlashParams({
    required this.intent,
    required this.pageId,
    required this.blockId,
    this.selectionPlain,
    required this.blockPlain,
  });

  final AiSlashIntent intent;
  final String pageId;
  final String blockId;

  /// Selección no colapsada en texto plano (markdown o Quill), si existe.
  final String? selectionPlain;

  /// Contenido actual del bloque en texto plano (puede incluir el comando `/` recién borrado en sync).
  final String blockPlain;
}

AiSlashIntent? aiSlashIntentFromCmdKey(String cmdKey) {
  switch (cmdKey) {
    case 'cmd_ai_summarize':
      return AiSlashIntent.summarize;
    case 'cmd_ai_continue':
      return AiSlashIntent.continueWriting;
    case 'cmd_ai_explain':
      return AiSlashIntent.explain;
    case 'cmd_ai_action_items':
      return AiSlashIntent.actionItems;
    case 'cmd_ai_todo':
      return AiSlashIntent.todo;
    case 'cmd_ai_mindmap':
      return AiSlashIntent.mindmap;
    case 'cmd_ai_table':
      return AiSlashIntent.table;
    case 'cmd_ai_improve':
      return AiSlashIntent.improve;
    case 'cmd_ai_translate':
      return AiSlashIntent.translate;
    default:
      return null;
  }
}
