import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../models/block.dart';
import '../../../models/folio_page.dart';
import '../../../session/vault_session.dart';

const _blockTypes = <String, String>{
  'paragraph': 'Párrafo',
  'h1': 'Encabezado 1',
  'h2': 'Encabezado 2',
  'h3': 'Encabezado 3',
  'bullet': 'Lista',
  'todo': 'Tarea',
};

class BlockEditor extends StatefulWidget {
  const BlockEditor({super.key, required this.session});

  final VaultSession session;

  @override
  State<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<BlockEditor> {
  static const _uuid = Uuid();
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  final List<VoidCallback> _textListeners = [];
  final List<VoidCallback> _focusDecorListeners = [];
  String? _boundPageId;
  var _ignoreShortcuts = false;
  int? _pendingFocusIndex;
  int? _pendingCursorOffset;
  String? _pendingFocusBlockId;
  int? _hoveredBlockIndex;
  final List<String> _controllerBlockIds = [];

  VaultSession get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _s.addListener(_onSession);
    _syncControllers();
  }

  @override
  void dispose() {
    _s.removeListener(_onSession);
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    final n = _controllers.length;
    for (var i = 0; i < n; i++) {
      if (i < _textListeners.length) {
        _controllers[i].removeListener(_textListeners[i]);
      }
      if (i < _focusDecorListeners.length) {
        _focusNodes[i].removeListener(_focusDecorListeners[i]);
      }
      _controllers[i].dispose();
      _focusNodes[i].dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
    _textListeners.clear();
    _focusDecorListeners.clear();
    _controllerBlockIds.clear();
  }

  bool _controllersMismatchPage(FolioPage page) {
    if (page.id != _boundPageId) return true;
    if (page.blocks.length != _controllers.length) return true;
    if (page.blocks.length != _controllerBlockIds.length) return true;
    for (var i = 0; i < page.blocks.length; i++) {
      if (page.blocks[i].id != _controllerBlockIds[i]) return true;
    }
    return false;
  }

  void _onSession() {
    if (!mounted) return;
    final page = _s.selectedPage;
    if (page == null) {
      _disposeControllers();
      _boundPageId = null;
      setState(() {});
      return;
    }
    if (_controllersMismatchPage(page)) {
      _syncControllers();
    }
    setState(() {});
  }

  void _syncControllers() {
    final page = _s.selectedPage;
    final pendingIdx = _pendingFocusIndex;
    final pendingOff = _pendingCursorOffset;
    final pendingBlockId = _pendingFocusBlockId;
    _pendingFocusIndex = null;
    _pendingCursorOffset = null;
    _pendingFocusBlockId = null;

    _disposeControllers();
    if (page == null) {
      _boundPageId = null;
      return;
    }
    _boundPageId = page.id;

    for (final b in page.blocks) {
      final bid = b.id;
      final pid = page.id;
      final c = TextEditingController(text: b.text);

      void textListener() {
        if (!mounted) return;
        final p = _s.selectedPage;
        if (p == null || p.id != pid) return;
        final idx = p.blocks.indexWhere((x) => x.id == bid);
        if (idx < 0) return;
        _syncBlockTextFromController(pid, bid, c.text, idx);
      }

      void focusDecorListener() {
        if (mounted) setState(() {});
      }

      c.addListener(textListener);
      _textListeners.add(textListener);

      final fn = FocusNode(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final p = _s.selectedPage;
          if (p?.id != pid) return KeyEventResult.ignored;
          final idx = p!.blocks.indexWhere((x) => x.id == bid);
          if (idx < 0) return KeyEventResult.ignored;
          return _handleBlockKey(p, bid, idx, c, event);
        },
      );
      fn.addListener(focusDecorListener);
      _focusDecorListeners.add(focusDecorListener);

      _controllers.add(c);
      _focusNodes.add(fn);
      _controllerBlockIds.add(bid);
    }

    var focusIdx = pendingIdx;
    var focusOff = pendingOff;
    if (pendingBlockId != null) {
      final j = page.blocks.indexWhere((b) => b.id == pendingBlockId);
      if (j >= 0) {
        focusIdx = j;
        focusOff ??= _controllers[j].selection.baseOffset.clamp(
              0,
              _controllers[j].text.length,
            );
      }
    }

    final idxToFocus = focusIdx;
    final offToFocus = focusOff;
    if (idxToFocus != null &&
        idxToFocus >= 0 &&
        idxToFocus < _focusNodes.length) {
      final iFocus = idxToFocus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (iFocus >= _focusNodes.length) return;
        _focusNodes[iFocus].requestFocus();
        if (offToFocus != null && iFocus < _controllers.length) {
          final len = _controllers[iFocus].text.length;
          final off = offToFocus.clamp(0, len);
          _controllers[iFocus].selection =
              TextSelection.collapsed(offset: off);
        }
      });
    }
  }

  KeyEventResult _handleBlockKey(
    FolioPage page,
    String blockId,
    int index,
    TextEditingController ctrl,
    KeyDownEvent event,
  ) {
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      final sel = ctrl.selection;
      if (!sel.isValid || sel.start != sel.end) {
        return KeyEventResult.ignored;
      }
      final at = sel.start;
      final text = ctrl.text;
      if (at == text.length) {
        _pendingFocusIndex = index + 1;
        _pendingCursorOffset = 0;
        _s.insertEmptyParagraphAfter(
          pageId: page.id,
          afterBlockId: blockId,
        );
      } else {
        final before = text.substring(0, at);
        final after = text.substring(at);
        _pendingFocusIndex = index + 1;
        _pendingCursorOffset = 0;
        _s.splitBlockAtCaret(
          pageId: page.id,
          blockId: blockId,
          before: before,
          after: after,
        );
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      final sel = ctrl.selection;
      if (!sel.isValid || sel.start != sel.end) {
        return KeyEventResult.ignored;
      }
      if (sel.start != 0) {
        return KeyEventResult.ignored;
      }
      if (page.blocks.length <= 1) {
        return KeyEventResult.ignored;
      }
      if (ctrl.text.isEmpty) {
        _pendingFocusIndex = index - 1;
        final prevLen =
            index > 0 ? page.blocks[index - 1].text.length : 0;
        _pendingCursorOffset = prevLen;
        _s.removeBlockIfMultiple(page.id, blockId);
        return KeyEventResult.handled;
      }
      _pendingFocusIndex = index - 1;
      _pendingCursorOffset = page.blocks[index - 1].text.length;
      _s.mergeBlockUp(page.id, blockId);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Lógica de texto del bloque (nombre estable para hot reload; no renombrar a la ligera).
  void _syncBlockTextFromController(
    String pageId,
    String blockId,
    String text,
    int index,
  ) {
    if (_ignoreShortcuts) return;
    _s.updateBlockText(pageId, blockId, text);

    if (_tryMarkdownShortcut(pageId, blockId, text, index)) {
      return;
    }

    if (text == '/') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSlashMenu(context, pageId, blockId, index);
      });
    }
  }

  bool _tryMarkdownShortcut(
    String pageId,
    String blockId,
    String text,
    int index,
  ) {
    String? type;
    if (text == '# ') {
      type = 'h1';
    } else if (text == '## ') {
      type = 'h2';
    } else if (text == '### ') {
      type = 'h3';
    } else if (text == '- ' || text == '* ') {
      type = 'bullet';
    } else if (text == '[] ' || text == '[ ] ') {
      type = 'todo';
    }
    if (type == null) return false;

    _ignoreShortcuts = true;
    _s.changeBlockType(pageId, blockId, type);
    _s.updateBlockText(pageId, blockId, '');
    if (index < _controllers.length) {
      _controllers[index].value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    _ignoreShortcuts = false;
    return true;
  }

  Future<void> _showSlashMenu(
    BuildContext context,
    String pageId,
    String blockId,
    int index,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return _SlashMenuSheet(types: _blockTypes);
      },
    );
    if (!mounted || choice == null) return;
    _ignoreShortcuts = true;
    _s.changeBlockType(pageId, blockId, choice);
    _s.updateBlockText(pageId, blockId, '');
    if (index < _controllers.length) {
      _controllers[index].value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    _ignoreShortcuts = false;
  }

  TextStyle _styleFor(String type, TextTheme theme) {
    switch (type) {
      case 'h1':
        return theme.headlineSmall!.copyWith(fontWeight: FontWeight.w700);
      case 'h2':
        return theme.titleLarge!.copyWith(fontWeight: FontWeight.w600);
      case 'h3':
        return theme.titleMedium!.copyWith(fontWeight: FontWeight.w600);
      default:
        return theme.bodyLarge!.copyWith(height: 1.45, fontSize: 15);
    }
  }

  void _addBlock(String pageId) {
    final page = _s.selectedPage;
    if (page == null || page.blocks.isEmpty) return;
    _pendingFocusIndex = page.blocks.length;
    _pendingCursorOffset = 0;
    _s.insertBlockAfter(
      pageId: pageId,
      afterBlockId: page.blocks.last.id,
      block: FolioBlock(
        id: '${pageId}_${_uuid.v4()}',
        type: 'paragraph',
        text: '',
      ),
    );
  }

  Color _blockRowFill(ColorScheme scheme, int index, FocusNode focus) {
    final hovered = _hoveredBlockIndex == index;
    final focused = focus.hasFocus;
    if (focused) {
      return scheme.surfaceContainerHighest.withValues(alpha: 0.4);
    }
    if (hovered) {
      return scheme.surfaceContainerHighest.withValues(alpha: 0.22);
    }
    return Colors.transparent;
  }

  void _moveBlock(String pageId, String blockId, int delta) {
    final idx = _s.selectedPage?.blocks.indexWhere((b) => b.id == blockId) ?? -1;
    if (idx < 0) return;
    _pendingFocusIndex = idx + delta;
    _pendingCursorOffset = _controllers[idx].selection.baseOffset.clamp(
      0,
      _controllers[idx].text.length,
    );
    _s.moveBlock(pageId, blockId, delta);
  }

  void _onBlocksReordered(FolioPage page, int oldIndex, int newIndex) {
    String? focusId;
    for (var i = 0; i < _focusNodes.length; i++) {
      if (_focusNodes[i].hasFocus) {
        focusId = page.blocks[i].id;
        break;
      }
    }
    _pendingFocusBlockId = focusId;
    _s.reorderBlockAt(page.id, oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final page = _s.selectedPage;
    if (page == null) {
      return const Center(child: Text('Selecciona una página'));
    }
    if (_controllers.length != page.blocks.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final p = _s.selectedPage;
        if (p != null && _controllers.length != p.blocks.length) {
          _syncControllers();
          setState(() {});
        }
      });
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFamily: 'monospace',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            'Enter: bloque nuevo · Shift+Enter: línea · / menú · # espacio, ##, ###, - o * espacio, [] espacio',
            style: mono,
          ),
        ),
        Expanded(
          child: Theme(
            data: theme.copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              buildDefaultDragHandles: false,
              itemCount: page.blocks.length,
              onReorder: (oldIndex, newIndex) =>
                  _onBlocksReordered(page, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final b = page.blocks[index];
                final ctrl = _controllers[index];
                final focus = _focusNodes[index];
                final style = _styleFor(b.type, theme.textTheme);
                final showActions =
                    _hoveredBlockIndex == index || focus.hasFocus;

                return KeyedSubtree(
                  key: ValueKey(b.id),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredBlockIndex = index),
                    onExit: (_) {
                      if (_hoveredBlockIndex == index) {
                        setState(() => _hoveredBlockIndex = null);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.only(bottom: 1),
                      decoration: BoxDecoration(
                        color: _blockRowFill(scheme, index, focus),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _buildBlockRow(
                        context: context,
                        scheme: scheme,
                        page: page,
                        block: b,
                        index: index,
                        ctrl: ctrl,
                        focus: focus,
                        style: style,
                        showActions: showActions,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _addBlock(page.id),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Añadir bloque'),
        ),
      ],
    );
  }

  PopupMenuButton<String> _blockMenuButton({
    required FolioPage page,
    required FolioBlock b,
    required int index,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 22),
      tooltip: 'Opciones del bloque',
      style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
      onSelected: (v) {
        if (v == 'del' && page.blocks.length > 1) {
          if (index > 0) {
            _pendingFocusIndex = index - 1;
            _pendingCursorOffset = page.blocks[index - 1].text.length;
          } else {
            _pendingFocusIndex = 0;
            _pendingCursorOffset = 0;
          }
          _s.removeBlockIfMultiple(page.id, b.id);
        } else if (v.startsWith('t:')) {
          _s.changeBlockType(page.id, b.id, v.substring(2));
        } else if (v == 'up' && index > 0) {
          _moveBlock(page.id, b.id, -1);
        } else if (v == 'down' && index < page.blocks.length - 1) {
          _moveBlock(page.id, b.id, 1);
        }
      },
      itemBuilder: (ctx) => [
        if (index > 0)
          const PopupMenuItem(value: 'up', child: Text('Mover arriba')),
        if (index < page.blocks.length - 1)
          const PopupMenuItem(value: 'down', child: Text('Mover abajo')),
        const PopupMenuDivider(),
        ..._blockTypes.entries.map(
          (e) => PopupMenuItem(
            value: 't:${e.key}',
            child: Text(e.value),
          ),
        ),
        if (page.blocks.length > 1) const PopupMenuDivider(),
        if (page.blocks.length > 1)
          const PopupMenuItem(value: 'del', child: Text('Eliminar bloque')),
      ],
    );
  }

  static const _trailingSlotWidth = 40.0;
  static const _dragGutterWidth = 22.0;
  /// Ancho fijo para viñeta / checkbox / hueco: alinea el texto con Notion.
  static const _markerColumnWidth = 30.0;

  Widget _blockTrailing({
    required bool showActions,
    required PopupMenuButton<String> menu,
  }) {
    return SizedBox(
      width: _trailingSlotWidth,
      child: showActions
          ? Align(
              alignment: Alignment.centerRight,
              child: menu,
            )
          : null,
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
  }) {
    final menu = _blockMenuButton(page: page, b: block, index: index);
    final iconColor = scheme.onSurfaceVariant.withValues(alpha: 0.85);

    final dragHandle = showActions
        ? Tooltip(
            message: 'Arrastrar para reordenar',
            waitDuration: const Duration(milliseconds: 400),
            child: ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: SizedBox(
                  width: _dragGutterWidth,
                  height: 32,
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 20,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          )
        : SizedBox(width: _dragGutterWidth, height: 32);

    Widget marker;
    switch (block.type) {
      case 'todo':
        marker = SizedBox(
          width: _markerColumnWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(-2, 0),
              child: Checkbox(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                value: block.checked ?? false,
                onChanged: (v) {
                  if (v != null) {
                    _s.setBlockChecked(page.id, block.id, v);
                  }
                },
              ),
            ),
          ),
        );
        break;
      case 'bullet':
        marker = SizedBox(
          width: _markerColumnWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Text(
                '•',
                style: style.copyWith(height: 1.0),
              ),
            ),
          ),
        );
        break;
      default:
        marker = SizedBox(width: _markerColumnWidth);
    }

    final isParagraph = block.type == 'paragraph';
    final isListLine = block.type == 'todo' || block.type == 'bullet';

    final field = TextField(
      controller: ctrl,
      focusNode: focus,
      maxLines: null,
      minLines: isParagraph ? 2 : 1,
      style: style,
      textAlignVertical:
          isParagraph ? TextAlignVertical.top : TextAlignVertical.center,
      decoration: isListLine
          ? InputDecoration.collapsed(
              hintText: block.type == 'todo' ? 'Tarea…' : '',
            )
          : InputDecoration(
              border: InputBorder.none,
              isDense: true,
              filled: false,
              hintText: isParagraph ? 'Escribe…  /  para menú' : null,
              contentPadding: EdgeInsets.zero,
            ),
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 2, 4, 2),
      child: Row(
        crossAxisAlignment: isParagraph
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          dragHandle,
          marker,
          Expanded(child: field),
          _blockTrailing(showActions: showActions, menu: menu),
        ],
      ),
    );
  }
}

class _SlashMenuSheet extends StatefulWidget {
  const _SlashMenuSheet({required this.types});

  final Map<String, String> types;

  @override
  State<_SlashMenuSheet> createState() => _SlashMenuSheetState();
}

class _SlashMenuSheetState extends State<_SlashMenuSheet> {
  final _filter = TextEditingController();
  var _query = '';

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() => _query = _filter.text));
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final entries = widget.types.entries.where((e) {
      if (q.isEmpty) return true;
      return e.key.contains(q) ||
          e.value.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _filter,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar tipo de bloque…',
                prefixIcon: Icon(Icons.search, size: 22),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text('Tipo de bloque'),
                  dense: true,
                ),
                ...entries.map(
                  (e) => ListTile(
                    title: Text(e.value),
                    subtitle: Text(e.key, style: const TextStyle(fontSize: 12)),
                    onTap: () => Navigator.pop(context, e.key),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
