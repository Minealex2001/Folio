part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Debug/test-only entry points for [BlockEditorState], invoked directly by
/// widget tests via `GlobalKey<BlockEditorState>` (not part of the app's
/// normal runtime UI surface). Split out of `block_editor_state.dart` since
/// this is the lowest-coupling, most self-contained slice of that file.
mixin _BlockEditorDebugApi on State<BlockEditor> {
  BlockEditorState get _debugSelf => this as BlockEditorState;

  /// Solo pruebas: fuerza selección y actualiza la barra en Overlay (Quill/markdown).
  @visibleForTesting
  void debugShowFormatToolbarOverlayForTest() {
    final st = _debugSelf;
    if (!mounted || widget.readOnlyMode || st._controllerBlockIds.isEmpty) {
      return;
    }
    final bid = st._controllerBlockIds.first;
    final qc = st._quillByBlockId[bid];
    if (qc != null) {
      final plain = qc.document.toPlainText();
      if (plain.isEmpty) return;
      final end = math.min(4, plain.length);
      qc.updateSelection(
        TextSelection(baseOffset: 0, extentOffset: end),
        quill.ChangeSource.local,
      );
    } else {
      final c = st._controllers.first;
      if (c.text.isEmpty) return;
      final end = math.min(4, c.text.length);
      st._runWithShortcutsIgnored(() {
        c.selection = TextSelection(baseOffset: 0, extentOffset: end);
      });
    }
    st._selectionActiveBlockId = bid;
    setState(() {});
    st._updateFormatToolbarOverlay();
  }

  /// Solo pruebas: offset del caret en texto plano del bloque Quill activo.
  @visibleForTesting
  int? debugLiveQuillCaretOffsetForBlock(String blockId) {
    final st = _debugSelf;
    final page = st._s.selectedPage;
    if (page == null) return null;
    FolioBlock? block;
    for (final b in page.blocks) {
      if (b.id == blockId) {
        block = b;
        break;
      }
    }
    if (block == null || !_stylableBlockTypes.contains(block.type)) {
      return null;
    }
    if (!st._quillByBlockId.containsKey(blockId)) {
      st._ensureQuillController(pageId: page.id, block: block);
    }
    return st._liveCaretPlainOffset(blockId);
  }

  /// Solo pruebas: escribe texto en un bloque Quill y vacía el debounce.
  @visibleForTesting
  void debugSimulateQuillTypingForTest(String blockId, String text) {
    final st = _debugSelf;
    final page = st._s.selectedPage;
    if (page == null || text.isEmpty) return;
    FolioBlock? block;
    for (final b in page.blocks) {
      if (b.id == blockId) {
        block = b;
        break;
      }
    }
    if (block == null || !_stylableBlockTypes.contains(block.type)) return;
    final qc = st._ensureQuillController(pageId: page.id, block: block);
    var plain = qc.document.toPlainText();
    if (plain.endsWith('\n')) {
      plain = plain.substring(0, plain.length - 1);
    }
    final offset = qc.selection.isValid
        ? qc.selection.baseOffset.clamp(0, plain.length)
        : plain.length;
    qc.replaceText(offset, 0, text, null);
    final after = qc.document.toPlainText();
    var end = after.length;
    if (after.endsWith('\n') && end > 0) {
      end -= 1;
    }
    qc.updateSelection(
      TextSelection.collapsed(offset: end),
      quill.ChangeSource.local,
    );
    st._quillFlushNowByBlockId[blockId]?.call();
  }

  /// Solo pruebas: prepara centinela sin ejecutar el post-frame de foco.
  @visibleForTesting
  int? debugPrepareTrailingSentinelCaretTest(String blockId) {
    final st = _debugSelf;
    final page = st._s.selectedPage;
    if (page == null) return null;
    FolioBlock? block;
    for (final b in page.blocks) {
      if (b.id == blockId) {
        block = b;
        break;
      }
    }
    if (block == null || !_stylableBlockTypes.contains(block.type)) {
      return null;
    }
    final qc = st._ensureQuillController(pageId: page.id, block: block);
    final idx = page.blocks.indexWhere((b) => b.id == blockId);
    if (idx >= 0 && idx < st._focusNodes.length) {
      st._focusNodes[idx].requestFocus();
    }
    qc.replaceText(0, 0, 'hola', null);
    qc.updateSelection(
      const TextSelection.collapsed(offset: 4),
      quill.ChangeSource.local,
    );
    st._quillFlushNowByBlockId[blockId]?.call();
    if (!st._ensureTrailingSentinel(page)) {
      final pageAfter = st._s.selectedPage;
      if (pageAfter != null && st._controllersMismatchPage(pageAfter)) {
        if (st._canReorderControllersOnly(pageAfter)) {
          st._reorderControllersLikePage(pageAfter);
        } else {
          st._syncControllers();
        }
      }
    }
    return st._pendingCursorOffset;
  }

  @visibleForTesting
  int? debugQuillRawCaretForTest(String blockId) {
    final st = _debugSelf;
    final qc = st._quillByBlockId[blockId];
    if (qc == null || !qc.selection.isValid) return null;
    return qc.selection.baseOffset;
  }

  /// Solo pruebas: pide foco directamente para el `FocusNode` de un bloque
  /// por id, sin depender de que un `tester.tap` real llegue a impactar el
  /// widget correcto (ver nota en `debugSendKeyEventToFocusedBlockForTest`).
  @visibleForTesting
  void debugRequestFocusForBlockForTest(String blockId) {
    final st = _debugSelf;
    final idx = st._controllerBlockIds.indexOf(blockId);
    if (idx < 0 || idx >= st._focusNodes.length) return;
    st._focusNodes[idx].requestFocus();
  }

  /// Solo pruebas: id del bloque cuyo `FocusNode` tiene el foco ahora mismo,
  /// o `null` si ninguno lo tiene — mismo patrón de búsqueda ya usado por
  /// `debugInvokeTryInsertNewBlockForTest`, extraído para verificar destino
  /// de foco tras crear/duplicar/eliminar (Fase B3 del rediseño UX).
  @visibleForTesting
  String? debugFocusedBlockIdForTest() {
    final st = _debugSelf;
    for (var i = 0; i < st._focusNodes.length; i++) {
      if (i >= st._controllerBlockIds.length) continue;
      if (st._focusNodes[i].hasFocus) return st._controllerBlockIds[i];
    }
    return null;
  }

  /// Solo pruebas: invoca directamente `_onBlockMenuChosen` (el menú "⋮" de
  /// un bloque) sin tener que localizar/pulsar el `PopupMenuButton` real,
  /// cuya visibilidad depende del estado de hover — frágil en un harness
  /// sin ratón real. Mismo patrón que el resto de hooks de este archivo.
  @visibleForTesting
  void debugInvokeBlockMenuActionForTest(
    String action,
    FolioPage page,
    FolioBlock block,
    int index,
  ) {
    final st = _debugSelf;
    st._onBlockMenuChosen(action, st.context, page, block, index);
  }

  /// Solo pruebas: selecciona un conjunto de bloques por id directamente,
  /// sin depender de simular shift/ctrl-click reales (frágil en este
  /// harness, ver nota en `debugSendKeyEventToFocusedBlockForTest`).
  @visibleForTesting
  void debugSelectBlocksForTest(Iterable<String> blockIds) {
    final st = _debugSelf;
    st.setState(() {
      st._selectedBlockIds
        ..clear()
        ..addAll(blockIds);
    });
  }

  /// Solo pruebas: expone `_isContiguousSelection` (Fases E1-E3).
  @visibleForTesting
  bool debugIsContiguousSelectionForTest(FolioPage page) =>
      _debugSelf._isContiguousSelection(page, _debugSelf._selectedBlockIds);

  /// Solo pruebas: expone `_convertSelectionToColumns` (Fase E2).
  @visibleForTesting
  void debugConvertSelectionToColumnsForTest(FolioPage page, int columnCount) =>
      _debugSelf._convertSelectionToColumns(page, columnCount);

  /// Solo pruebas: expone `_groupSelectionIntoSection` (Fase E3).
  @visibleForTesting
  void debugGroupSelectionIntoSectionForTest(
    FolioPage page, {
    required String title,
  }) => _debugSelf._groupSelectionIntoSection(page, title: title);

  /// Solo pruebas: expone `_aiPaletteCommands` (Fase C1) — comandos de IA
  /// del Command Palette, reutilizando el mismo pipeline de ejecución que
  /// el slash menu (`_dispatchAiSlashFromToolbar`).
  @visibleForTesting
  List<PaletteCommand> debugAiPaletteCommandsForTest(AppLocalizations l10n) =>
      _debugSelf._aiPaletteCommands(l10n);

  /// Solo pruebas: enruta un [KeyEvent] arbitrario a través del mismo
  /// `_handleBlockKey` que `FocusNode.onKeyEvent` usa en producción para el
  /// bloque actualmente enfocado — evita la fragilidad observada al
  /// simular teclado real vía `tester.sendKeyEvent` en este harness (el
  /// foco del `Listener`/`GestureDetector` que envuelve cada fila no
  /// siempre coincide con el `FocusNode` real tras un `tester.tap`). Usado
  /// por los tests de caracterización de gestos (Fase B1 del rediseño UX).
  @visibleForTesting
  KeyEventResult? debugSendKeyEventToFocusedBlockForTest(KeyEvent event) {
    final st = _debugSelf;
    final page = st._s.selectedPage;
    if (page == null) return null;
    for (var i = 0; i < st._focusNodes.length; i++) {
      if (i >= st._controllerBlockIds.length || i >= st._controllers.length) {
        continue;
      }
      if (st._focusNodes[i].hasFocus) {
        final blockId = st._controllerBlockIds[i];
        final idx = page.blocks.indexWhere((b) => b.id == blockId);
        if (idx < 0) return null;
        return st._handleBlockKey(page, blockId, idx, st._controllers[i], event);
      }
    }
    return null;
  }

  /// Solo pruebas: misma inserción que Enter / Ctrl+Enter en el bloque enfocado.
  @visibleForTesting
  bool debugInvokeTryInsertNewBlockForTest({required bool force}) {
    final st = _debugSelf;
    final page = st._s.selectedPage;
    if (page == null) return false;
    for (var i = 0; i < st._focusNodes.length; i++) {
      if (i >= st._controllerBlockIds.length || i >= st._controllers.length) {
        continue;
      }
      if (st._focusNodes[i].hasFocus) {
        final blockId = st._controllerBlockIds[i];
        final idx = page.blocks.indexWhere((b) => b.id == blockId);
        if (idx < 0) return false;
        return st._tryInsertNewBlockFromCurrentCaret(
          page: page,
          blockId: blockId,
          index: idx,
          ctrl: st._controllers[i],
          force: force,
        );
      }
    }
    return false;
  }
}
