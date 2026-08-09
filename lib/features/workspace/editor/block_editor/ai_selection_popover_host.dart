part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Fase D1 del rediseño UX del editor — popover de IA anclado a selección,
/// estilo Raycast: en vez de que el botón "✨" de la barra de formato
/// dispare siempre el mismo intent fijo (`AiSlashIntent.explain`, el
/// comportamiento de antes de esta fase — ver `onAskQuill` en
/// `block_editor_state_format_toolbar.dart`), ahora abre un mini-buscador
/// con las acciones de IA como resultados filtrables.
///
/// Reutiliza literalmente el mismo widget `CommandPaletteOverlay` (Fase C2)
/// y el mismo proveedor `_aiPaletteCommands` (Fase C1) — este popover es,
/// en la práctica, un Command Palette en miniatura con el dominio acotado a
/// "acciones de IA sobre el bloque actual". No es un segundo pipeline de
/// IA ni un segundo widget de lista rankeada.
mixin _AiSelectionPopoverHost on State<BlockEditor> {
  BlockEditorState get _aiPopoverSelf => this as BlockEditorState;

  OverlayEntry? _aiSelectionOverlayEntry;
  final Map<String, int> _aiSelectionRecentScores = {};

  bool get isAiSelectionPopoverOpen => _aiSelectionOverlayEntry != null;

  /// [blockIds]: Fase 0 del roadmap de producto — bloques de la selección
  /// multi-bloque activa (si hay más de uno), para que el popover ofrezca
  /// acciones de IA sobre toda la selección en vez de solo [blockId].
  void showAiSelectionPopover({required String blockId, List<String>? blockIds}) {
    if (_aiSelectionOverlayEntry != null) return;
    final st = _aiPopoverSelf;
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (context) => CommandPaletteOverlay(
        resolveCommands: () => st._aiPaletteCommands(
          AppLocalizations.of(context),
          anchorBlockId: blockId,
          anchorBlockIds: blockIds,
        ),
        recentScores: _aiSelectionRecentScores,
        onDismiss: dismissAiSelectionPopover,
        onCommandExecuted: (id) {
          _aiSelectionRecentScores.update(id, (v) => v + 1, ifAbsent: () => 1);
        },
      ),
    );
    _aiSelectionOverlayEntry = entry;
    overlay.insert(entry);
    if (mounted) setState(() {});
  }

  void dismissAiSelectionPopover() {
    _aiSelectionOverlayEntry?.remove();
    _aiSelectionOverlayEntry = null;
    if (mounted) setState(() {});
  }
}
