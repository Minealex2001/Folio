part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Fase G2 del rediseño UX del editor — host del mini-flujo de variables de
/// las smart templates (`/meeting`, `/sprint`, `/roadmap`). Mismo patrón de
/// `OverlayEntry` ya establecido por `_CommandPaletteOverlayHost` (Fase C2)
/// y `_AiSelectionPopoverHost` (Fase D1): show/dismiss + getter de estado.
///
/// Si la plantilla no tiene variables (ej. `/roadmap`), se salta el overlay
/// por completo y se insertan los bloques directamente — el mini-flujo solo
/// existe para las plantillas que realmente necesitan datos del usuario.
mixin _SmartTemplateFlowHost on State<BlockEditor> {
  BlockEditorState get _smartTemplateFlowSelf => this as BlockEditorState;

  OverlayEntry? _smartTemplateOverlayEntry;

  bool get isSmartTemplateFlowOpen => _smartTemplateOverlayEntry != null;

  void showSmartTemplateFlow({
    required SmartTemplateDefinition template,
    required String pageId,
    required String blockId,
  }) {
    if (template.variables.isEmpty) {
      _insertSmartTemplateBlocks(
        template: template,
        pageId: pageId,
        blockId: blockId,
        answers: const {},
      );
      return;
    }
    if (_smartTemplateOverlayEntry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (context) => SmartTemplateFlowOverlay(
        template: template,
        onComplete: (answers) {
          dismissSmartTemplateFlow();
          _insertSmartTemplateBlocks(
            template: template,
            pageId: pageId,
            blockId: blockId,
            answers: answers,
          );
        },
        onCancel: dismissSmartTemplateFlow,
      ),
    );
    _smartTemplateOverlayEntry = entry;
    overlay.insert(entry);
    if (mounted) setState(() {});
  }

  void dismissSmartTemplateFlow() {
    _smartTemplateOverlayEntry?.remove();
    _smartTemplateOverlayEntry = null;
    if (mounted) setState(() {});
  }

  void _insertSmartTemplateBlocks({
    required SmartTemplateDefinition template,
    required String pageId,
    required String blockId,
    required Map<String, String> answers,
  }) {
    final st = _smartTemplateFlowSelf;
    final l10n = AppLocalizations.of(context);
    final blocks = template.buildBlocks(
      answers,
      () => '${pageId}_${BlockEditorState._uuid.v4()}',
      l10n,
    );
    if (blocks.isEmpty) return;
    st._s.insertBlocksAfterMany(
      pageId: pageId,
      afterBlockId: blockId,
      blocks: blocks,
    );
    st._s.removeBlockIfMultiple(pageId, blockId);
  }
}
