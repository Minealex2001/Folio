part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Fase C1 del rediseño UX del editor — proveedor real de comandos de IA
/// para el Command Palette, colocado junto a su fuente de datos real
/// (`BlockEditorState._focusedBlockId`/`_dispatchAiSlashFromToolbar`) en vez
/// de construirse "a ciegas" desde fuera. Reutiliza exactamente el mismo
/// pipeline de ejecución que ya usan el menú `/` y la barra de formato
/// (Fase D1 del plan pedía justo esto: exponer los intents independientes
/// del punto de entrada de slash) — el Palette no añade un segundo camino
/// de ejecución de IA, solo un disparador más.
mixin _AiPaletteProvider on State<BlockEditor> {
  BlockEditorState get _aiPaletteSelf => this as BlockEditorState;

  /// [anchorBlockId]: el bloque que estaba enfocado justo antes de abrir el
  /// Palette. Necesario porque el propio campo de búsqueda del Palette
  /// roba el foco del bloque en cuanto se abre (`_focusedBlockId` pasa a
  /// `null` de inmediato) — sin este ancla, "resumir"/"traducir"/etc.
  /// nunca estarían disponibles desde el Palette, aunque el usuario
  /// tuviera un bloque enfocado un instante antes. `null` = sin bloque
  /// enfocado al abrir (uso fuera del Palette, ej. en el propio slash menu
  /// donde `_focusedBlockId` sigue siendo válido en vivo).
  List<PaletteCommand> _aiPaletteCommands(
    AppLocalizations l10n, {
    String? anchorBlockId,
  }) {
    final st = _aiPaletteSelf;
    final page = st._s.selectedPage;
    if (page == null) return const [];

    PaletteCommand intentCommand({
      required String id,
      required String label,
      required String hint,
      required IconData icon,
      required AiSlashIntent intent,
    }) {
      String? targetBlockId() => anchorBlockId ?? st._focusedBlockId;
      return PaletteCommand(
        id: id,
        label: label,
        hint: hint,
        icon: icon,
        category: PaletteCommandCategory.ai,
        // Solo disponible con un bloque enfocado (o anclado al abrir el
        // Palette) — mismo requisito que el slash menu, que siempre opera
        // sobre el bloque actual.
        isAvailable: () => targetBlockId() != null,
        execute: () {
          final blockId = targetBlockId();
          if (blockId == null) return;
          unawaited(
            st._dispatchAiSlashFromToolbar(
              intent: intent,
              pageId: page.id,
              blockId: blockId,
            ),
          );
        },
      );
    }

    return [
      intentCommand(
        id: 'cmd_ai_summarize',
        label: l10n.blockEditorCmdAiSummarize,
        hint: l10n.blockEditorCmdAiSummarizeHint,
        icon: Icons.summarize_rounded,
        intent: AiSlashIntent.summarize,
      ),
      intentCommand(
        id: 'cmd_ai_continue',
        label: l10n.blockEditorCmdAiContinue,
        hint: l10n.blockEditorCmdAiContinueHint,
        icon: Icons.auto_awesome_motion_rounded,
        intent: AiSlashIntent.continueWriting,
      ),
      intentCommand(
        id: 'cmd_ai_explain',
        label: l10n.blockEditorCmdAiExplain,
        hint: l10n.blockEditorCmdAiExplainHint,
        icon: Icons.help_outline_rounded,
        intent: AiSlashIntent.explain,
      ),
      intentCommand(
        id: 'cmd_ai_action_items',
        label: l10n.blockEditorCmdAiActionItems,
        hint: l10n.blockEditorCmdAiActionItemsHint,
        icon: Icons.checklist_rounded,
        intent: AiSlashIntent.actionItems,
      ),
      intentCommand(
        id: 'cmd_ai_todo',
        label: l10n.blockEditorCmdAiTodo,
        hint: l10n.blockEditorCmdAiTodoHint,
        icon: Icons.task_alt_rounded,
        intent: AiSlashIntent.todo,
      ),
      intentCommand(
        id: 'cmd_ai_mindmap',
        label: l10n.blockEditorCmdAiMindmap,
        hint: l10n.blockEditorCmdAiMindmapHint,
        icon: Icons.account_tree_rounded,
        intent: AiSlashIntent.mindmap,
      ),
      intentCommand(
        id: 'cmd_ai_table',
        label: l10n.blockEditorCmdAiTable,
        hint: l10n.blockEditorCmdAiTableHint,
        icon: Icons.table_chart_rounded,
        intent: AiSlashIntent.table,
      ),
      intentCommand(
        id: 'cmd_ai_improve',
        label: l10n.blockEditorCmdAiImprove,
        hint: l10n.blockEditorCmdAiImproveHint,
        icon: Icons.edit_note_rounded,
        intent: AiSlashIntent.improve,
      ),
      intentCommand(
        id: 'cmd_ai_translate',
        label: l10n.blockEditorCmdAiTranslate,
        hint: l10n.blockEditorCmdAiTranslateHint,
        icon: Icons.translate_rounded,
        intent: AiSlashIntent.translate,
      ),
    ];
  }
}
