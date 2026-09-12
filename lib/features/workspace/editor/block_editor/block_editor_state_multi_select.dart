part of 'package:folio/features/workspace/editor/block_editor.dart';

/// Multi-block selection, shift/ctrl-click and drag-select, plus the
/// block-level move/duplicate/delete/reorder actions and row-building
/// helpers that operate on that selection. Split out of
/// `block_editor_state.dart` as one bounded region. The static layout
/// constants (`_menuSlotWidth`, `_dragGutterWidth`, `_markerColumnWidth`,
/// etc.) stay on `BlockEditorState` itself -- they're referenced by other
/// part files via the qualified `BlockEditorState._name` form, which only
/// resolves for statics declared directly on that class, not on a mixin
/// composed into it.
mixin _MultiSelectDragDrop on State<BlockEditor> {
  BlockEditorState get _selectionSelf => this as BlockEditorState;

  bool _isBlockSelected(String blockId) =>
      _selectionSelf._selectedBlockIds.contains(blockId);

  bool get _isAdditiveSelectionPressed {
    return HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
  }

  void _selectOnlyBlock(String blockId) {
    final st = _selectionSelf;
    setState(() {
      st._selectedBlockIds
        ..clear()
        ..add(blockId);
      st._selectionAnchorBlockId = blockId;
    });
  }

  void _toggleBlockSelection(String blockId) {
    final st = _selectionSelf;
    setState(() {
      if (st._selectedBlockIds.contains(blockId)) {
        st._selectedBlockIds.remove(blockId);
        if (st._selectionAnchorBlockId == blockId) {
          st._selectionAnchorBlockId = st._selectedBlockIds.isEmpty
              ? null
              : st._selectedBlockIds.first;
        }
      } else {
        st._selectedBlockIds.add(blockId);
        st._selectionAnchorBlockId = blockId;
      }
    });
  }

  void _selectBlockRange(FolioPage page, String blockId) {
    final st = _selectionSelf;
    final anchorId = st._selectionAnchorBlockId;
    if (anchorId == null) {
      _selectOnlyBlock(blockId);
      return;
    }
    final anchorIndex = page.blocks.indexWhere((b) => b.id == anchorId);
    final targetIndex = page.blocks.indexWhere((b) => b.id == blockId);
    if (anchorIndex < 0 || targetIndex < 0) {
      _selectOnlyBlock(blockId);
      return;
    }
    final start = math.min(anchorIndex, targetIndex);
    final end = math.max(anchorIndex, targetIndex);
    setState(() {
      st._selectedBlockIds
        ..clear()
        ..addAll(page.blocks.sublist(start, end + 1).map((b) => b.id));
    });
  }

  void _handleBlockSelection(
    FolioPage page,
    String blockId, {
    FocusNode? focusNode,
    bool requestFocus = true,
  }) {
    final st = _selectionSelf;
    if (HardwareKeyboard.instance.isShiftPressed) {
      _selectBlockRange(page, blockId);
    } else if (_isAdditiveSelectionPressed) {
      _toggleBlockSelection(blockId);
    } else if (!_isBlockSelected(blockId) ||
        st._selectedBlockIds.length > 1) {
      _selectOnlyBlock(blockId);
    }
    if (requestFocus && focusNode != null) {
      st._transitioningBlockIds.add(blockId);
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        focusNode.requestFocus();
        st._transitioningBlockIds.remove(blockId);
        setState(() {});
      });
    }
  }

  Set<String> _rangeBlockIds(
    FolioPage page,
    String startBlockId,
    String endBlockId,
  ) {
    final startIndex = page.blocks.indexWhere((b) => b.id == startBlockId);
    final endIndex = page.blocks.indexWhere((b) => b.id == endBlockId);
    if (startIndex < 0 || endIndex < 0) return <String>{endBlockId};
    final rangeStart = math.min(startIndex, endIndex);
    final rangeEnd = math.max(startIndex, endIndex);
    return page.blocks
        .sublist(rangeStart, rangeEnd + 1)
        .map((block) => block.id)
        .toSet();
  }

  void _beginDragSelection(
    FolioPage page,
    String blockId, {
    FocusNode? focusNode,
  }) {
    final st = _selectionSelf;
    st._dragSelectionActive = true;
    st._dragSelectionOriginBlockId = blockId;
    st._dragSelectionBaseIds = _isAdditiveSelectionPressed
        ? (Set<String>.from(st._selectedBlockIds)..remove(blockId))
        : <String>{};
    _handleBlockSelection(page, blockId, focusNode: focusNode);
  }

  void _updateDragSelection(FolioPage page, String blockId) {
    final st = _selectionSelf;
    if (!st._dragSelectionActive) return;
    final originBlockId = st._dragSelectionOriginBlockId;
    if (originBlockId == null) return;
    final nextIds = _rangeBlockIds(page, originBlockId, blockId);
    final combinedIds = <String>{...st._dragSelectionBaseIds, ...nextIds};
    if (setEquals(combinedIds, st._selectedBlockIds)) return;
    setState(() {
      st._selectedBlockIds
        ..clear()
        ..addAll(combinedIds);
      st._selectionAnchorBlockId = originBlockId;
    });
  }

  void _endDragSelection() {
    final st = _selectionSelf;
    st._dragSelectionActive = false;
    st._dragSelectionOriginBlockId = null;
    st._dragSelectionBaseIds.clear();
  }

  List<String> _selectedIdsForAction(FolioPage page, String triggerBlockId) {
    final st = _selectionSelf;
    if (st._selectedBlockIds.contains(triggerBlockId) &&
        st._selectedBlockIds.length > 1) {
      return page.blocks
          .where((block) => st._selectedBlockIds.contains(block.id))
          .map((block) => block.id)
          .toList();
    }
    return [triggerBlockId];
  }

  void _deleteSelectedBlocks(FolioPage page, List<String> blockIds) {
    final st = _selectionSelf;
    if (blockIds.isEmpty || page.blocks.length <= 1) return;
    final existingIds = page.blocks
        .where((b) => blockIds.contains(b.id))
        .map((b) => b.id)
        .toList();
    if (existingIds.isEmpty) return;
    // Nunca dejes la página sin bloques: limita el borrado a N-1.
    final maxDeletable = page.blocks.length - 1;
    final idsToDelete = existingIds.take(maxDeletable).toList();
    if (idsToDelete.isEmpty) return;
    final idsToDeleteSet = idsToDelete.toSet();
    final survivors = page.blocks
        .where((b) => !idsToDeleteSet.contains(b.id))
        .toList();
    final firstSelectedIndex = page.blocks.indexWhere(
      (b) => idsToDeleteSet.contains(b.id),
    );
    final fallbackIndex = math.max(0, firstSelectedIndex - 1);
    final targetIndex = math.min(fallbackIndex, survivors.length - 1);
    final targetBlock = survivors[targetIndex];
    st._pendingFocusBlockId = targetBlock.id;
    st._pendingCursorOffset = targetBlock.text.length;
    st._s.removeBlocksIfMultiple(page.id, idsToDelete);
    setState(() {
      st._selectedBlockIds
        ..clear()
        ..add(targetBlock.id);
      st._selectionAnchorBlockId = targetBlock.id;
    });
  }

  void _duplicateSelectedBlocks(FolioPage page, List<String> blockIds) {
    final st = _selectionSelf;
    if (blockIds.isEmpty) return;
    final blocks = page.blocks.where((b) => blockIds.contains(b.id)).toList();
    if (blocks.isEmpty) return;
    final clones = st._s.cloneBlocksWithNewIds(page.id, blocks);
    if (clones.isEmpty) return;
    st._s.insertBlocksAfterMany(
      pageId: page.id,
      afterBlockId: blocks.last.id,
      blocks: clones,
    );
    st._pendingFocusBlockId = clones.first.id;
    st._pendingCursorOffset = clones.first.text.length;
    setState(() {
      st._selectedBlockIds
        ..clear()
        ..addAll(clones.map((b) => b.id));
      st._selectionAnchorBlockId = clones.first.id;
    });
  }

  /// Fases E1-E3 del rediseño UX del editor: "Agrupar" (columnas/sección)
  /// solo tiene sentido sobre una selección contigua en `page.blocks` — ni
  /// `FolioColumnsData` ni `Section.range` (Fase E0A) representan bloques
  /// dispersos. Pura, sin efectos, para poder deshabilitar el botón en la
  /// UI antes de que el usuario intente una acción que no puede completarse.
  bool _isContiguousSelection(FolioPage page, Set<String> ids) {
    if (ids.length < 2) return false;
    final indices = <int>[];
    for (var i = 0; i < page.blocks.length; i++) {
      if (ids.contains(page.blocks[i].id)) indices.add(i);
    }
    if (indices.length != ids.length) return false;
    for (var i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1] + 1) return false;
    }
    return true;
  }

  /// Fase E2 — convierte una selección contigua en un bloque `column_list`
  /// con [columnCount] columnas (2 o 3), reutilizando el tipo de bloque ya
  /// existente (`FolioColumnsData`) en vez de inventar un segundo primitivo
  /// de layout. Reparte los bloques seleccionados en tramos consecutivos
  /// (los primeros a la columna 1, los siguientes a la columna 2, ...) —
  /// `FolioColumnsData` no soporta anchos por ratio hoy (70/30 etc.), así
  /// que solo se ofrece el número de columnas, no la proporción.
  void _convertSelectionToColumns(FolioPage page, int columnCount) {
    assert(columnCount == 2 || columnCount == 3);
    final st = _selectionSelf;
    final ids = st._selectedBlockIds;
    if (!_isContiguousSelection(page, ids)) return;
    final selected = page.blocks.where((b) => ids.contains(b.id)).toList();
    if (selected.length < columnCount) return;

    final perColumn = (selected.length / columnCount).ceil();
    final columns = <FolioColumnData>[];
    for (var i = 0; i < columnCount; i++) {
      final start = i * perColumn;
      if (start >= selected.length) {
        columns.add(FolioColumnData.empty());
        continue;
      }
      final end = math.min(start + perColumn, selected.length);
      columns.add(FolioColumnData(blocks: selected.sublist(start, end)));
    }

    final columnsBlockId = '${page.id}_columns_${BlockEditorState._uuid.v4()}';
    st._s.insertBlockAfter(
      pageId: page.id,
      afterBlockId: selected.last.id,
      block: FolioBlock(
        id: columnsBlockId,
        type: 'column_list',
        text: FolioColumnsData(columns: columns).encode(),
      ),
    );
    st._s.removeBlocksIfMultiple(page.id, selected.map((b) => b.id).toList());
    setState(() {
      st._selectedBlockIds
        ..clear()
        ..add(columnsBlockId);
      st._selectionAnchorBlockId = columnsBlockId;
    });
  }

  /// Fase E3 — agrupa una selección contigua en una `Section` real (Fase
  /// E0A/E0B). Los bloques no se mueven ni se duplican, solo se referencian
  /// por rango — reutiliza `VaultSession.createSectionFromRange` tal cual.
  void _groupSelectionIntoSection(FolioPage page, {required String title}) {
    final st = _selectionSelf;
    final ids = st._selectedBlockIds;
    if (!_isContiguousSelection(page, ids)) return;
    final selected = page.blocks.where((b) => ids.contains(b.id)).toList();
    if (selected.isEmpty) return;
    st._s.createSectionFromRange(
      page.id,
      title: title,
      range: BlockRange(
        firstBlockId: selected.first.id,
        lastBlockId: selected.last.id,
      ),
    );
    _clearBlockSelection();
  }

  void _clearBlockSelection() {
    final st = _selectionSelf;
    if (st._selectedBlockIds.isEmpty) return;
    setState(() {
      st._selectedBlockIds.clear();
      st._selectionAnchorBlockId = null;
    });
  }

  void _moveBlock(String pageId, String blockId, int delta) {
    final st = _selectionSelf;
    final idx =
        st._s.selectedPage?.blocks.indexWhere((b) => b.id == blockId) ?? -1;
    if (idx < 0) return;
    st._pendingFocusIndex = idx + delta;
    st._pendingCursorOffset = st._controllers[idx].selection.baseOffset.clamp(
      0,
      st._controllers[idx].text.length,
    );
    st._s.moveBlock(pageId, blockId, delta);
  }

  void _duplicateBlock(FolioPage page, FolioBlock block, int index) {
    final st = _selectionSelf;
    final clones = st._s.cloneBlocksWithNewIds(page.id, [block]);
    if (clones.isEmpty) return;
    st._pendingFocusIndex = index + 1;
    st._pendingCursorOffset = clones.first.text.length;
    st._s.insertBlockAfter(
      pageId: page.id,
      afterBlockId: block.id,
      block: clones.first,
    );
  }

  void _onBlocksReordered(FolioPage page, int oldIndex, int newIndex) {
    final st = _selectionSelf;
    st._pendingFocusBlockId = st._focusedBlockId;
    st._s.reorderBlockAt(page.id, oldIndex, newIndex);
  }

  void _mutateTable(
    String pageId,
    String blockId,
    int index,
    void Function(FolioTableData d) op,
  ) {
    final st = _selectionSelf;
    final page = st._s.selectedPage;
    if (page == null) return;
    final bi = page.blocks.indexWhere((b) => b.id == blockId);
    if (bi < 0) return;
    final raw = page.blocks[bi].text;
    final d = FolioTableData.tryParse(raw) ?? FolioTableData.empty();
    op(d);
    d.normalize();
    final enc = d.encode();
    st._onTableEncoded(pageId, blockId, index, enc);
    setState(() {});
  }

  void _mutateDatabase(
    String pageId,
    String blockId,
    int index,
    void Function(FolioDatabaseData d) op,
  ) {
    final st = _selectionSelf;
    final page = st._s.selectedPage;
    if (page == null) return;
    final bi = page.blocks.indexWhere((b) => b.id == blockId);
    if (bi < 0) return;
    final raw = page.blocks[bi].text;
    final d = FolioDatabaseData.tryParse(raw) ?? FolioDatabaseData.empty();
    op(d);
    final enc = d.encode();
    st._onTableEncoded(pageId, blockId, index, enc);
    setState(() {});
  }

  int _orderedListNumber(List<FolioBlock> blocks, int index) {
    if (index < 0 || index >= blocks.length) return 1;
    if (blocks[index].type != 'numbered') return 1;
    final d = blocks[index].depth;
    var n = 1;
    for (var j = index - 1; j >= 0; j--) {
      final b = blocks[j];
      if (b.depth < d) break;
      if (b.depth == d) {
        if (b.type == 'numbered') {
          n++;
        } else {
          break;
        }
      }
    }
    return n;
  }

  Widget _blockMenuSlot({
    required bool showActions,
    required PopupMenuButton<String> menu,
  }) {
    final androidPhoneLayout = FolioAdaptive.isAndroidPhoneWidth(
      MediaQuery.sizeOf(context).width,
    );
    final compactReadOnlyMobile = widget.readOnlyMode && androidPhoneLayout;
    if (compactReadOnlyMobile) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: androidPhoneLayout
          ? BlockEditorState._menuSlotWidthPhone
          : BlockEditorState._menuSlotWidth,
      height: BlockEditorState._menuSlotHeight,
      child: IgnorePointer(
        ignoring: !showActions,
        child: AnimatedOpacity(
          opacity: showActions ? 1 : 0,
          duration: FolioMotion.short2,
          child: Align(alignment: Alignment.centerLeft, child: menu),
        ),
      ),
    );
  }

  /// Fila estilo Notion: asa de arrastre, marcador (viñeta / checkbox / hueco), texto.
  Widget _buildBlockRow({
    required BuildContext context,
    required ColorScheme scheme,
    required FolioPage page,
    required FolioBlock block,
    required int index,
    required TextEditingController ctrl,
    required FocusNode focus,
    required TextStyle style,
    required bool showActions,
    required bool showInlineEditControls,
  }) {
    return _selectionSelf._buildBlockRowDelegated(
      context: context,
      scheme: scheme,
      page: page,
      block: block,
      index: index,
      ctrl: ctrl,
      focus: focus,
      style: style,
      showActions: showActions,
      showInlineEditControls: showInlineEditControls,
    );
  }
}
