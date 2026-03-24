import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../data/vault_paths.dart';
import '../../../models/block.dart';
import '../../../models/folio_database_data.dart';
import '../../../models/folio_page.dart';
import '../../../models/folio_table_data.dart';
import '../../../session/vault_session.dart';
import 'code_block_languages.dart';
import 'database_block_editor.dart';
import 'file_video_previews.dart';
import 'folio_text_format.dart';
import 'table_block_editor.dart';

/// Metadatos para el selector visual de tipos (orden de aparición).
const blockTypeCatalog = <BlockTypeDef>[
  BlockTypeDef(
    key: 'paragraph',
    label: 'Párrafo',
    hint: 'Texto corrido sin formato',
    icon: Icons.notes_rounded,
    section: BlockTypeSection.text,
  ),
  BlockTypeDef(
    key: 'h1',
    label: 'Encabezado 1',
    hint: '#  ·  título destacado',
    icon: Icons.looks_one_rounded,
    section: BlockTypeSection.text,
  ),
  BlockTypeDef(
    key: 'h2',
    label: 'Encabezado 2',
    hint: '##  ·  sección',
    icon: Icons.looks_two_rounded,
    section: BlockTypeSection.text,
  ),
  BlockTypeDef(
    key: 'h3',
    label: 'Encabezado 3',
    hint: '###  ·  subtítulo',
    icon: Icons.looks_3_rounded,
    section: BlockTypeSection.text,
  ),
  BlockTypeDef(
    key: 'bullet',
    label: 'Lista con viñetas',
    hint: '-  o *  ·  lista no numerada',
    icon: Icons.format_list_bulleted_rounded,
    section: BlockTypeSection.list,
  ),
  BlockTypeDef(
    key: 'todo',
    label: 'Lista de tareas',
    hint: '[ ]  ·  casillas',
    icon: Icons.check_box_outlined,
    section: BlockTypeSection.list,
  ),
  BlockTypeDef(
    key: 'code',
    label: 'Código',
    hint: '/codigo  ·  ``` espacio',
    icon: Icons.code_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'image',
    label: 'Imagen',
    hint: '/imagen  ·  archivo en el cofre',
    icon: Icons.image_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'table',
    label: 'Tabla',
    hint: '/tabla  ·  celdas editables',
    icon: Icons.table_chart_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'database',
    label: 'Base de datos',
    hint: '/database  ·  tabla/tablero/calendario',
    icon: Icons.dataset_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'quote',
    label: 'Cita',
    hint: '”  ·  texto destacado',
    icon: Icons.format_quote_rounded,
    section: BlockTypeSection.text,
  ),
  BlockTypeDef(
    key: 'divider',
    label: 'Separador',
    hint: '---  ·  línea horizontal',
    icon: Icons.horizontal_rule_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'callout',
    label: 'Destacado',
    hint: '💡  ·  caja con icono',
    icon: Icons.lightbulb_outline_rounded,
    section: BlockTypeSection.text,
  ),
  BlockTypeDef(
    key: 'file',
    label: 'Archivo',
    hint: '/archivo  ·  adjunto',
    icon: Icons.attach_file_rounded,
    section: BlockTypeSection.media,
  ),
  BlockTypeDef(
    key: 'video',
    label: 'Video',
    hint: '/video  ·  reproductor',
    icon: Icons.play_circle_outline_rounded,
    section: BlockTypeSection.media,
  ),
];

enum BlockTypeSection { text, list, media }

String blockSectionTitle(BlockTypeSection s) {
  switch (s) {
    case BlockTypeSection.text:
      return 'Texto';
    case BlockTypeSection.list:
      return 'Listas';
    case BlockTypeSection.media:
      return 'Medios y datos';
  }
}

class BlockTypeDef {
  const BlockTypeDef({
    required this.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.section,
  });

  final String key;
  final String label;
  final String hint;
  final IconData icon;
  final BlockTypeSection section;
}

/// `null` si el texto del bloque no es comando `/…`; si no, filtro tras la `/` (puede ser vacío).
String? _slashFilterFromBlockText(String text) {
  if (!text.startsWith('/')) return null;
  if (text.contains('\n')) return null;
  final tail = text.substring(1);
  if (tail.contains(' ')) return null;
  return tail;
}

List<BlockTypeDef> _catalogFiltered(String q) {
  final qq = q.trim().toLowerCase();
  if (qq.isEmpty) return blockTypeCatalog;
  return blockTypeCatalog.where((d) {
    return d.key.contains(qq) ||
        d.label.toLowerCase().contains(qq) ||
        d.hint.toLowerCase().contains(qq);
  }).toList();
}

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

  /// Evita quitar el botón ⋮ del árbol mientras el popup está abierto (el ratón sale del `MouseRegion`).
  String? _menuOpenBlockId;
  final List<String> _controllerBlockIds = [];
  String? _slashBlockId;
  String? _slashPageId;
  final ScrollController _slashListScrollController = ScrollController();
  final Map<String, Future<File?>> _resolvedFileFutureByUrl = {};

  /// Bloque de texto cuya barra de formato sigue visible aunque el foco se mueva al pulsarla (p. ej. ScrollView).
  String? _formatStickyBlockId;
  Timer? _formatStickyClearTimer;

  VaultSession get _s => widget.session;

  static final RegExp _imageUrlExt = RegExp(
    r'\.(png|jpe?g|gif|webp|bmp|svg)(\?.*)?$',
    caseSensitive: false,
  );

  bool _isImageUrl(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    final uri = Uri.tryParse(t);
    if (uri == null) return false;
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) return false;
    return _imageUrlExt.hasMatch(
      uri.path + (uri.hasQuery ? '?${uri.query}' : ''),
    );
  }

  double _imageWidthFor(FolioBlock block) {
    return (block.imageWidth ?? 1.0).clamp(0.2, 1.0);
  }

  void _nudgeImageWidth(FolioPage page, FolioBlock block, double delta) {
    final next = (_imageWidthFor(block) + delta).clamp(0.2, 1.0);
    _s.setBlockImageWidth(page.id, block.id, next);
  }

  static const _slashFormatTypes = {
    'paragraph',
    'h1',
    'h2',
    'h3',
    'bullet',
    'todo',
    'quote',
    'callout',
  };

  void _syncFormatStickyBlockId() {
    _formatStickyClearTimer?.cancel();
    _formatStickyClearTimer = null;
    final page = _s.selectedPage;
    if (page == null) {
      _formatStickyBlockId = null;
      return;
    }
    for (var i = 0; i < _focusNodes.length; i++) {
      if (i >= page.blocks.length) break;
      if (_focusNodes[i].hasFocus) {
        final b = page.blocks[i];
        if (_slashFormatTypes.contains(b.type)) {
          _formatStickyBlockId = b.id;
        } else {
          _formatStickyBlockId = null;
        }
        return;
      }
    }
    _formatStickyClearTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      if (!_focusNodes.any((n) => n.hasFocus)) {
        setState(() => _formatStickyBlockId = null);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _s.addListener(_onSession);
    _syncControllers();
  }

  @override
  void dispose() {
    _formatStickyClearTimer?.cancel();
    _slashListScrollController.dispose();
    _resolvedFileFutureByUrl.clear();
    _s.removeListener(_onSession);
    _disposeControllers();
    super.dispose();
  }

  void _dismissInlineSlash({required bool clearTypedCommand}) {
    final id = _slashBlockId;
    final pid = _slashPageId;
    _slashBlockId = null;
    _slashPageId = null;
    if (clearTypedCommand && id != null && pid != null) {
      final idx = _controllerBlockIds.indexWhere((x) => x == id);
      if (idx >= 0) {
        final c = _controllers[idx];
        final t = c.text;
        if (_slashFilterFromBlockText(t) != null) {
          _ignoreShortcuts = true;
          c.value = const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          );
          _s.updateBlockText(pid, id, '');
          _ignoreShortcuts = false;
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _applyInlineSlashChoice(String typeKey) {
    final id = _slashBlockId;
    final pid = _slashPageId;
    if (id == null || pid == null) return;
    final idx = _controllerBlockIds.indexWhere((x) => x == id);
    _slashBlockId = null;
    _slashPageId = null;
    _ignoreShortcuts = true;

    // Remove the trailing slash command from the block's text
    _s.updateBlockText(pid, id, '');
    _s.changeBlockType(pid, id, typeKey);

    var newText = '';
    final pageAfter = _s.selectedPage;
    if (pageAfter != null) {
      final bi = pageAfter.blocks.indexWhere((b) => b.id == id);
      if (bi >= 0) {
        newText = pageAfter.blocks[bi].text;
      }
    }
    if (idx >= 0) {
      _controllers[idx].value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    _ignoreShortcuts = false;
    if (mounted) setState(() {});
    if (idx >= 0 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (idx >= _focusNodes.length) return;
        _focusNodes[idx].requestFocus();
        if (idx < _controllers.length) {
          _controllers[idx].selection = const TextSelection.collapsed(
            offset: 0,
          );
        }
      });
    }
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
    _slashBlockId = null;
    _slashPageId = null;
    _menuOpenBlockId = null;
    _formatStickyClearTimer?.cancel();
    _formatStickyClearTimer = null;
    _formatStickyBlockId = null;
  }

  bool _controllersMismatchPage(FolioPage page) {
    if (page.id != _boundPageId) return true;
    if (page.blocks.length != _controllers.length) return true;
    if (page.blocks.length != _controllerBlockIds.length) return true;
    for (var i = 0; i < page.blocks.length; i++) {
      if (page.blocks[i].id != _controllerBlockIds[i]) return true;
      final wantCode = page.blocks[i].type == 'code';
      final hasCode = _controllers[i] is CodeController;
      if (wantCode != hasCode) return true;
    }
    return false;
  }

  /// Solo reordenar: mismos bloques y tipos que ya tenemos en memoria.
  /// Evita dispose de [CodeField]/FocusNode (flutter_code_editor deja overlays/listeners rotos).
  bool _canReorderControllersOnly(FolioPage page) {
    if (page.id != _boundPageId) return false;
    if (page.blocks.length != _controllers.length ||
        page.blocks.length != _controllerBlockIds.length) {
      return false;
    }
    if (page.blocks.isEmpty) return true;

    final pageIds = page.blocks.map((b) => b.id).toList()..sort();
    final curIds = List<String>.from(_controllerBlockIds)..sort();
    if (pageIds.length != curIds.length) return false;
    for (var i = 0; i < pageIds.length; i++) {
      if (pageIds[i] != curIds[i]) return false;
    }

    for (final b in page.blocks) {
      final j = _controllerBlockIds.indexOf(b.id);
      if (j < 0) return false;
      final wantCode = b.type == 'code';
      final hasCode = _controllers[j] is CodeController;
      if (wantCode != hasCode) return false;
    }
    return true;
  }

  void _reorderControllersLikePage(FolioPage page) {
    final newControllers = <TextEditingController>[];
    final newFocusNodes = <FocusNode>[];
    final newTextListeners = <VoidCallback>[];
    final newFocusDecorListeners = <VoidCallback>[];
    final newIds = <String>[];

    for (final b in page.blocks) {
      final j = _controllerBlockIds.indexOf(b.id);
      newControllers.add(_controllers[j]);
      newFocusNodes.add(_focusNodes[j]);
      newTextListeners.add(_textListeners[j]);
      newFocusDecorListeners.add(_focusDecorListeners[j]);
      newIds.add(b.id);
    }

    _controllers
      ..clear()
      ..addAll(newControllers);
    _focusNodes
      ..clear()
      ..addAll(newFocusNodes);
    _textListeners
      ..clear()
      ..addAll(newTextListeners);
    _focusDecorListeners
      ..clear()
      ..addAll(newFocusDecorListeners);
    _controllerBlockIds
      ..clear()
      ..addAll(newIds);

    _pendingFocusBlockId = null;
    _pendingFocusIndex = null;
    _pendingCursorOffset = null;
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
      if (_canReorderControllersOnly(page)) {
        _reorderControllersLikePage(page);
      } else {
        _syncControllers();
      }
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
      final TextEditingController c = b.type == 'code'
          ? CodeController(
              text: b.text,
              language: modeForLanguageId(b.codeLanguage),
            )
          : TextEditingController(text: b.text);

      void textListener() {
        if (!mounted) return;
        final p = _s.selectedPage;
        if (p == null || p.id != pid) return;
        final idx = p.blocks.indexWhere((x) => x.id == bid);
        if (idx < 0) return;
        _syncBlockTextFromController(pid, bid, c.text, idx);
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

      void focusDecorListener() {
        if (!mounted) return;
        _syncFormatStickyBlockId();
        final slashBid = _slashBlockId;
        if (slashBid != null) {
          final slashIdx = _controllerBlockIds.indexWhere((x) => x == slashBid);
          if (slashIdx >= 0 && !_focusNodes[slashIdx].hasFocus) {
            final otherBlockFocused = _focusNodes.asMap().entries.any(
              (e) => e.key != slashIdx && e.value.hasFocus,
            );
            if (otherBlockFocused) {
              _dismissInlineSlash(clearTypedCommand: true);
              return;
            }
          }
        }
        setState(() {});
      }

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
          _controllers[iFocus].selection = TextSelection.collapsed(offset: off);
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
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _s.unindentBlock(page.id, blockId);
      } else {
        _s.indentBlock(page.id, blockId);
      }
      return KeyEventResult.handled;
    }

    final blockType = page.blocks[index].type;
    if (blockType == 'code' &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }

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
      final curType = page.blocks[index].type;
      if (at == text.length) {
        _pendingFocusIndex = index + 1;
        _pendingCursorOffset = 0;
        if (curType == 'bullet' || curType == 'todo') {
          _s.insertBlockAfter(
            pageId: page.id,
            afterBlockId: blockId,
            block: FolioBlock(
              id: '${page.id}_${_uuid.v4()}',
              type: curType,
              text: '',
              checked: curType == 'todo' ? false : null,
            ),
          );
        } else {
          _s.insertEmptyParagraphAfter(pageId: page.id, afterBlockId: blockId);
        }
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

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_slashBlockId == blockId) {
        _dismissInlineSlash(clearTypedCommand: true);
        return KeyEventResult.handled;
      }
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
        final prevLen = index > 0 ? page.blocks[index - 1].text.length : 0;
        _pendingCursorOffset = prevLen;
        _s.removeBlockIfMultiple(page.id, blockId);
        return KeyEventResult.handled;
      }
      final prevLen = page.blocks[index - 1].text.length;
      final merged = _s.mergeBlockUp(page.id, blockId);
      if (!merged) {
        return KeyEventResult.ignored;
      }
      _pendingFocusIndex = index - 1;
      _pendingCursorOffset = prevLen;
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
    final pg = _s.selectedPage;
    if (pg == null || pg.id != pageId) return;
    final bi = pg.blocks.indexWhere((b) => b.id == blockId);
    if (bi < 0) return;
    final btype = pg.blocks[bi].type;
    _s.updateBlockText(pageId, blockId, text);
    if (btype != 'image' && _isImageUrl(text)) {
      _ignoreShortcuts = true;
      _s.changeBlockType(pageId, blockId, 'image');
      _s.updateBlockText(pageId, blockId, text.trim());
      if (index < _controllers.length) {
        _controllers[index].value = TextEditingValue(
          text: text.trim(),
          selection: TextSelection.collapsed(offset: text.trim().length),
        );
      }
      _ignoreShortcuts = false;
      return;
    }
    const slashTypes = {
      'paragraph',
      'h1',
      'h2',
      'h3',
      'bullet',
      'todo',
      'quote',
      'callout',
    };
    if (!slashTypes.contains(btype)) {
      return;
    }

    if (_tryMarkdownShortcut(pageId, blockId, text, index)) {
      if (_slashBlockId == blockId) {
        _dismissInlineSlash(clearTypedCommand: false);
      }
      return;
    }

    final slashFilter = _slashFilterFromBlockText(text);
    if (slashFilter != null) {
      final open = _slashBlockId != blockId;
      _slashPageId = pageId;
      _slashBlockId = blockId;
      setState(() {});
      if (open) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_slashListScrollController.hasClients) {
            _slashListScrollController.jumpTo(0);
          }
        });
      }
    } else if (_slashBlockId == blockId) {
      _dismissInlineSlash(clearTypedCommand: false);
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
    } else if (text == '``` ') {
      type = 'code';
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

  Future<String?> _openBlockTypePicker(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
      builder: (ctx) => BlockTypePickerSheet(catalog: blockTypeCatalog),
    );
  }

  TextStyle _styleFor(String type, TextTheme theme) {
    switch (type) {
      case 'h1':
        return theme.headlineSmall!.copyWith(fontWeight: FontWeight.w700);
      case 'h2':
        return theme.titleLarge!.copyWith(fontWeight: FontWeight.w600);
      case 'h3':
        return theme.titleMedium!.copyWith(fontWeight: FontWeight.w600);
      case 'code':
        return theme.bodyMedium!.copyWith(
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.4,
        );
      default:
        return theme.bodyLarge!.copyWith(height: 1.45, fontSize: 15);
    }
  }

  void _onTableEncoded(String pageId, String blockId, int index, String enc) {
    if (_ignoreShortcuts) return;
    _ignoreShortcuts = true;
    _s.updateBlockText(pageId, blockId, enc);
    if (index >= 0 && index < _controllers.length) {
      _controllers[index].value = TextEditingValue(
        text: enc,
        selection: TextSelection.collapsed(offset: enc.length),
      );
    }
    _ignoreShortcuts = false;
  }

  /// En escritorio `image_picker` suele lanzar [MissingPluginException]; ahí usamos diálogo nativo.
  bool get _pickImageViaFileDialog {
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  Future<void> _pickImageForBlock(
    String pageId,
    String blockId,
    int index,
  ) async {
    File? file;
    if (_pickImageViaFileDialog) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );
      final path = result?.files.single.path;
      if (path != null) {
        file = File(path);
      }
    } else {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery);
      if (x != null) {
        file = File(x.path);
      }
    }
    if (!mounted || file == null || !file.existsSync()) return;
    final rel = await VaultPaths.importAttachmentFile(file);
    if (!mounted) return;
    _ignoreShortcuts = true;
    _s.updateBlockText(pageId, blockId, rel);
    if (index < _controllers.length) {
      _controllers[index].value = TextEditingValue(
        text: rel,
        selection: TextSelection.collapsed(offset: rel.length),
      );
    }
    _ignoreShortcuts = false;
    setState(() {});
  }

  Future<void> _clearImageBlock(
    String pageId,
    String blockId,
    int index,
  ) async {
    _ignoreShortcuts = true;
    _s.updateBlockText(pageId, blockId, '');
    if (index < _controllers.length) {
      _controllers[index].clear();
    }
    _ignoreShortcuts = false;
    setState(() {});
  }

  Future<void> _pickFileForBlock(String pageId, String blockId) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final rel = await VaultPaths.importAttachmentFile(
        File(result.files.single.path!),
        preserveExtension: true,
        preserveFileName: true,
      );
      _s.updateBlockUrl(pageId, blockId, rel);
    }
  }

  Future<void> _pickVideoForBlock(String pageId, String blockId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      final rel = await VaultPaths.importAttachmentFile(
        File(result.files.single.path!),
        preserveExtension: true,
        preserveFileName: true,
      );
      _s.updateBlockUrl(pageId, blockId, rel);
    }
  }

  void _clearBlockUrl(String pageId, String blockId) {
    _s.updateBlockUrl(pageId, blockId, null);
    if (mounted) setState(() {});
  }

  Future<File?> _resolveBlockUrlFile(String? rawUrl) async {
    final raw0 = rawUrl?.trim();
    if (raw0 == null || raw0.isEmpty) return null;
    final normalized = raw0.replaceAll(r'\', '/');

    Future<File?> tryFilePath(String path) async {
      final f = File(path);
      return f.existsSync() ? f : null;
    }

    try {
      if (normalized.startsWith('file://')) {
        final fromUri = await tryFilePath(Uri.parse(normalized).toFilePath());
        if (fromUri != null) return fromUri;
      }

      final direct = await tryFilePath(raw0);
      if (direct != null) return direct;

      if (normalized.startsWith('${VaultPaths.attachmentsDirName}/') ||
          !p.isAbsolute(raw0)) {
        final vault = await VaultPaths.vaultDirectory();
        final candidate = await tryFilePath(p.join(vault.path, normalized));
        if (candidate != null) return candidate;
      }

      // Fallback tolerante para rutas antiguas/movidas: buscar por nombre en attachments.
      final base = p.basename(normalized);
      if (base.isNotEmpty) {
        final vault = await VaultPaths.vaultDirectory();
        final dir = Directory(
          p.join(vault.path, VaultPaths.attachmentsDirName),
        );
        if (dir.existsSync()) {
          for (final e in dir.listSync(followLinks: false)) {
            if (e is File && p.basename(e.path) == base) {
              return e;
            }
          }
        }
      }
    } catch (_) {
      // Ignoramos y devolvemos null para que la UI muestre estado recuperable.
    }
    return null;
  }

  Future<File?> _resolveBlockUrlFileCached(String? rawUrl) {
    final key = rawUrl?.trim();
    if (key == null || key.isEmpty) return Future<File?>.value(null);
    return _resolvedFileFutureByUrl.putIfAbsent(
      key,
      () => _resolveBlockUrlFile(key),
    );
  }

  Future<void> _openBlockUrlExternal(String? rawUrl) async {
    final file = await _resolveBlockUrlFile(rawUrl);
    if (file == null) return;
    await launchUrl(Uri.file(file.path));
  }

  Future<String?> _pickEmoji(BuildContext context) async {
    String? selectedEmoji;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SizedBox(
          height: 300,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              selectedEmoji = emoji.emoji;
              Navigator.pop(ctx);
            },
          ),
        );
      },
    );
    return selectedEmoji;
  }

  List<CodeLanguageOption> _codeLanguageOptionsForBlock(FolioBlock block) {
    final out = List<CodeLanguageOption>.from(kCodeLanguagePickerOptions);
    final s = block.codeLanguage?.trim();
    if (s != null && s.isNotEmpty && !out.any((o) => o.id == s)) {
      out.insert(
        0,
        CodeLanguageOption(id: s, label: s, icon: codeLanguageIcon(s)),
      );
    }
    return out;
  }

  String _codeLangDropdownValue(FolioBlock block) {
    final s = block.codeLanguage?.trim();
    if (s == null || s.isEmpty) return 'dart';
    final items = _codeLanguageOptionsForBlock(block);
    return items.any((o) => o.id == s) ? s : 'dart';
  }

  String _codeLangLabelForId(String id) {
    for (final o in kCodeLanguagePickerOptions) {
      if (o.id == id) return o.label;
    }
    return id;
  }

  void _onCodeLanguagePicked(
    String pageId,
    String blockId,
    int index,
    String languageId,
  ) {
    _s.setBlockCodeLanguage(pageId, blockId, languageId);
    if (index >= 0 && index < _controllers.length) {
      _pendingFocusIndex = index;
      final base = _controllers[index].selection.baseOffset;
      _pendingCursorOffset = base >= 0 ? base : _controllers[index].text.length;
    }
    if (mounted) setState(() {});
  }

  Future<String?> _openCodeLanguageSheet(
    BuildContext context,
    FolioBlock block,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: scheme.scrim.withValues(alpha: 0.4),
      builder: (ctx) {
        final items = _codeLanguageOptionsForBlock(block);
        final selectedId = _codeLangDropdownValue(block);
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Material(
              color: scheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 26,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lenguaje del código',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Text(
                      'Resaltado de sintaxis según el lenguaje elegido',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final o = items[i];
                        final selected = o.id == selectedId;
                        final icon = iconForCodeLanguageOption(o);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: selected
                                ? scheme.primaryContainer.withValues(
                                    alpha: 0.45,
                                  )
                                : scheme.surfaceContainerLow.withValues(
                                    alpha: 0.85,
                                  ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: selected
                                    ? scheme.primary.withValues(alpha: 0.45)
                                    : scheme.outlineVariant.withValues(
                                        alpha: 0.35,
                                      ),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.pop(ctx, o.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: scheme.primaryContainer
                                          .withValues(alpha: 0.65),
                                      child: Icon(
                                        icon,
                                        size: 22,
                                        color: scheme.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            o.label,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          if (o.label != o.id)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Text(
                                                o.id,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                      fontFamily: 'monospace',
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: scheme.primary,
                                        size: 26,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _imageBlockBody(
    ColorScheme scheme,
    FolioBlock block,
    FolioPage page,
    int index,
    bool showControls,
  ) {
    final rel = block.text.trim();
    if (rel.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 36,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).noImageHint,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            TextButton.icon(
              onPressed: () =>
                  unawaited(_pickImageForBlock(page.id, block.id, index)),
              icon: const Icon(Icons.upload_rounded, size: 20),
              label: Text(AppLocalizations.of(context).chooseImage),
            ),
          ],
        ),
      );
    }

    final widthFactor = _imageWidthFor(block);
    final isRemote = rel.startsWith('http://') || rel.startsWith('https://');
    return FutureBuilder<Directory>(
      key: ValueKey(rel),
      future: VaultPaths.vaultDirectory(),
      builder: (context, snap) {
        if (!isRemote && !snap.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        File? file;
        if (!isRemote) {
          file = File(p.join(snap.data!.path, rel));
        }
        if (!isRemote && (file == null || !file.existsSync())) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              AppLocalizations.of(context).fileNotFound,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showControls)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _nudgeImageWidth(page, block, -0.1),
                      icon: const Icon(Icons.remove, size: 16),
                      label: const Text('Menos'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _nudgeImageWidth(page, block, 0.1),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Mas'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          _s.setBlockImageWidth(page.id, block.id, 0.5),
                      child: const Text('50%'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          _s.setBlockImageWidth(page.id, block.id, 0.75),
                      child: const Text('75%'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          _s.setBlockImageWidth(page.id, block.id, 1.0),
                      child: const Text('100%'),
                    ),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                final targetW = (maxW * widthFactor).clamp(120.0, maxW);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: targetW,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 380),
                        child: isRemote
                            ? Image.network(
                                rel,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).couldNotLoadImage,
                                        style: TextStyle(
                                          color: scheme.error,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                              )
                            : Image.file(
                                file!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).couldNotLoadImage,
                                        style: TextStyle(
                                          color: scheme.error,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (showControls)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ancho: ${(widthFactor * 100).round()}%',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
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
    final idx =
        _s.selectedPage?.blocks.indexWhere((b) => b.id == blockId) ?? -1;
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
      return Center(child: Text(AppLocalizations.of(context).selectPage));
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

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Enter: bloque nuevo (en código: Enter = línea) · Shift+Enter: línea · / tipos · # · ## · ### · - · * · [] · ``` espacio · tabla/imagen en / · formato: barra al enfocar o ** _ <u> ` ~~ · vista previa al salir',
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
                      _hoveredBlockIndex == index ||
                      focus.hasFocus ||
                      _menuOpenBlockId == b.id ||
                      MediaQuery.sizeOf(context).width < 900;

                  return KeyedSubtree(
                    key: ValueKey(b.id),
                    child: MouseRegion(
                      onEnter: (_) =>
                          setState(() => _hoveredBlockIndex = index),
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
            label: Text(AppLocalizations.of(context).addBlock),
          ),
        ],
      ),
    );
  }

  PopupMenuButton<String> _blockMenuButton({
    required BuildContext menuContext,
    required FolioPage page,
    required FolioBlock b,
    required int index,
  }) {
    return PopupMenuButton<String>(
      icon: Semantics(
        button: true,
        label: AppLocalizations.of(context).blockOptions,
        child: Icon(Icons.more_vert_rounded, size: 22),
      ),
      tooltip: AppLocalizations.of(context).blockOptions,
      style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
      onOpened: () => setState(() => _menuOpenBlockId = b.id),
      onCanceled: () {
        if (_menuOpenBlockId == b.id) {
          setState(() => _menuOpenBlockId = null);
        }
      },
      onSelected: (v) {
        setState(() => _menuOpenBlockId = null);
        if (v == 'del' && page.blocks.length > 1) {
          if (index > 0) {
            _pendingFocusIndex = index - 1;
            _pendingCursorOffset = page.blocks[index - 1].text.length;
          } else {
            _pendingFocusIndex = 0;
            _pendingCursorOffset = 0;
          }
          _s.removeBlockIfMultiple(page.id, b.id);
        } else if (v == 'ai_rewrite') {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final c = TextEditingController();
            final go = await showDialog<bool>(
              context: menuContext,
              builder: (ctx) => AlertDialog(
                title: const Text('Reescribir con IA'),
                content: TextField(
                  controller: c,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Ejemplo: hazlo más claro y breve',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
            );
            if (go != true || c.text.trim().isEmpty) return;
            try {
              await _s.rewriteBlockWithAi(
                pageId: page.id,
                blockId: b.id,
                instruction: c.text.trim(),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error IA: $e')));
            }
          });
        } else if (v == 'pick_type') {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final choice = await _openBlockTypePicker(menuContext);
            if (!mounted || choice == null) return;
            _s.changeBlockType(page.id, b.id, choice);
            final p2 = _s.selectedPage;
            if (p2 != null && mounted) {
              final j = p2.blocks.indexWhere((x) => x.id == b.id);
              if (j >= 0 && j < _controllers.length) {
                final nb = p2.blocks[j];
                _ignoreShortcuts = true;
                _controllers[j].value = TextEditingValue(
                  text: nb.text,
                  selection: TextSelection.collapsed(offset: nb.text.length),
                );
                _ignoreShortcuts = false;
              }
            }
            if (mounted) setState(() {});
          });
        } else if (v == 'up' && index > 0) {
          _moveBlock(page.id, b.id, -1);
        } else if (v == 'down' && index < page.blocks.length - 1) {
          _moveBlock(page.id, b.id, 1);
        } else if (v == 'img_pick') {
          unawaited(_pickImageForBlock(page.id, b.id, index));
        } else if (v == 'img_clear') {
          unawaited(_clearImageBlock(page.id, b.id, index));
        } else if (v == 'file_pick') {
          unawaited(_pickFileForBlock(page.id, b.id));
        } else if (v == 'file_clear') {
          _clearBlockUrl(page.id, b.id);
        } else if (v == 'video_pick') {
          unawaited(_pickVideoForBlock(page.id, b.id));
        } else if (v == 'video_clear') {
          _clearBlockUrl(page.id, b.id);
        } else if (v == 'table_row_add') {
          _mutateTable(page.id, b.id, index, (d) => d.addRow());
        } else if (v == 'table_row_rem') {
          _mutateTable(page.id, b.id, index, (d) => d.removeLastRow());
        } else if (v == 'table_col_add') {
          _mutateTable(page.id, b.id, index, (d) => d.addCol());
        } else if (v == 'table_col_rem') {
          _mutateTable(page.id, b.id, index, (d) => d.removeLastCol());
        } else if (v == 'db_row_add') {
          _mutateDatabase(page.id, b.id, index, (d) {
            d.rows.add(FolioDbRow(id: '${page.id}_r_${_uuid.v4()}'));
          });
        } else if (v == 'db_col_add') {
          _mutateDatabase(page.id, b.id, index, (d) {
            d.properties.add(
              FolioDbProperty(
                id: 'p_${_uuid.v4()}',
                name: 'Propiedad ${d.properties.length + 1}',
                type: FolioDbPropertyType.text,
              ),
            );
          });
        } else if (v == 'code_lang') {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final id = await _openCodeLanguageSheet(menuContext, b);
            if (!mounted || id == null) return;
            _onCodeLanguagePicked(page.id, b.id, index, id);
          });
        }
      },
      itemBuilder: (ctx) {
        final data = b.type == 'table' ? FolioTableData.tryParse(b.text) : null;
        final db = b.type == 'database'
            ? FolioDatabaseData.tryParse(b.text)
            : null;
        final rows = data?.rowCount ?? 0;
        final cols = data?.cols ?? 0;
        return [
          if (_s.aiEnabled)
            const PopupMenuItem(
              value: 'ai_rewrite',
              child: Text('Reescribir con IA…'),
            ),
          if (index > 0)
            const PopupMenuItem(value: 'up', child: Text('Mover arriba')),
          if (index < page.blocks.length - 1)
            const PopupMenuItem(value: 'down', child: Text('Mover abajo')),
          if (b.type == 'image') ...[
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'img_pick',
              child: Text('Elegir imagen…'),
            ),
            if (b.text.isNotEmpty)
              const PopupMenuItem(
                value: 'img_clear',
                child: Text('Quitar imagen'),
              ),
          ],
          if (b.type == 'code') ...[
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'code_lang',
              child: Text('Lenguaje del código…'),
            ),
          ],
          if (b.type == 'file') ...[
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'file_pick',
              child: Text('Cambiar archivo…'),
            ),
            if ((b.url ?? '').trim().isNotEmpty)
              const PopupMenuItem(
                value: 'file_clear',
                child: Text('Quitar archivo'),
              ),
          ],
          if (b.type == 'video') ...[
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'video_pick',
              child: Text('Cambiar video…'),
            ),
            if ((b.url ?? '').trim().isNotEmpty)
              const PopupMenuItem(
                value: 'video_clear',
                child: Text('Quitar video'),
              ),
          ],
          if (b.type == 'table' && data != null) ...[
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'table_row_add',
              child: Text('Añadir fila'),
            ),
            if (rows > 1)
              const PopupMenuItem(
                value: 'table_row_rem',
                child: Text('Quitar última fila'),
              ),
            const PopupMenuItem(
              value: 'table_col_add',
              child: Text('Añadir columna'),
            ),
            if (cols > 1)
              const PopupMenuItem(
                value: 'table_col_rem',
                child: Text('Quitar última columna'),
              ),
          ],
          if (b.type == 'database' && db != null) ...[
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'db_row_add',
              child: Text('Añadir fila'),
            ),
            const PopupMenuItem(
              value: 'db_col_add',
              child: Text('Añadir propiedad'),
            ),
          ],
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'pick_type',
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_motion_rounded,
                  size: 20,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Cambiar tipo de bloque…')),
              ],
            ),
          ),
          if (page.blocks.length > 1) const PopupMenuDivider(),
          if (page.blocks.length > 1)
            const PopupMenuItem(value: 'del', child: Text('Eliminar bloque')),
        ];
      },
    );
  }

  void _mutateTable(
    String pageId,
    String blockId,
    int index,
    void Function(FolioTableData d) op,
  ) {
    final page = _s.selectedPage;
    if (page == null) return;
    final bi = page.blocks.indexWhere((b) => b.id == blockId);
    if (bi < 0) return;
    final raw = page.blocks[bi].text;
    final d = FolioTableData.tryParse(raw) ?? FolioTableData.empty();
    op(d);
    d.normalize();
    final enc = d.encode();
    _onTableEncoded(pageId, blockId, index, enc);
    setState(() {});
  }

  void _mutateDatabase(
    String pageId,
    String blockId,
    int index,
    void Function(FolioDatabaseData d) op,
  ) {
    final page = _s.selectedPage;
    if (page == null) return;
    final bi = page.blocks.indexWhere((b) => b.id == blockId);
    if (bi < 0) return;
    final raw = page.blocks[bi].text;
    final d = FolioDatabaseData.tryParse(raw) ?? FolioDatabaseData.empty();
    op(d);
    final enc = d.encode();
    _onTableEncoded(pageId, blockId, index, enc);
    setState(() {});
  }

  static const _menuSlotWidth = 40.0;
  static const _dragGutterWidth = 22.0;

  /// Ancho fijo para viñeta / checkbox / hueco: alinea el texto con Notion.
  static const _markerColumnWidth = 30.0;

  Widget _blockMenuSlot({
    required bool showActions,
    required PopupMenuButton<String> menu,
  }) {
    return SizedBox(
      width: _menuSlotWidth,
      child: showActions
          ? Align(alignment: Alignment.centerLeft, child: menu)
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
    final menu = _blockMenuButton(
      menuContext: context,
      page: page,
      b: block,
      index: index,
    );
    final iconColor = scheme.onSurfaceVariant.withValues(alpha: 0.85);

    final dragHandle = showActions
        ? Tooltip(
            message: AppLocalizations.of(context).dragToReorder,
            waitDuration: const Duration(milliseconds: 400),
            child: ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: AppLocalizations.of(context).dragToReorder,
                button: true,
                child: _DragHandleWidget(iconColor: iconColor),
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
            child: Semantics(
              label: 'Marcar tarea completada',
              toggled: block.checked ?? false,
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
              child: Text('•', style: style.copyWith(height: 1.0)),
            ),
          ),
        );
        break;
      default:
        marker = SizedBox(width: _markerColumnWidth);
    }

    final theme = Theme.of(context);

    if (block.type == 'image') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: Focus(
                focusNode: focus,
                child: GestureDetector(
                  onTap: () => focus.requestFocus(),
                  behavior: HitTestBehavior.opaque,
                  child: _imageBlockBody(
                    scheme,
                    block,
                    page,
                    index,
                    showActions || focus.hasFocus,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'table') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: TableBlockEditor(
                json: block.text,
                scheme: scheme,
                textTheme: theme.textTheme,
                firstCellFocusNode: focus,
                onChanged: (enc) =>
                    _onTableEncoded(page.id, block.id, index, enc),
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'database') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: DatabaseBlockEditor(
                json: block.text,
                scheme: scheme,
                textTheme: theme.textTheme,
                onChanged: (enc) =>
                    _onTableEncoded(page.id, block.id, index, enc),
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'code') {
      final codeCtrl = ctrl as CodeController;
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: MenuAnchor(
                        style: MenuStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            scheme.surfaceContainerHigh,
                          ),
                          surfaceTintColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                          shadowColor: WidgetStatePropertyAll(
                            scheme.shadow.withValues(alpha: 0.14),
                          ),
                          elevation: const WidgetStatePropertyAll(8),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(vertical: 8),
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        menuChildren: [
                          for (final o in _codeLanguageOptionsForBlock(block))
                            MenuItemButton(
                              leadingIcon: Icon(
                                iconForCodeLanguageOption(o),
                                size: 20,
                              ),
                              trailingIcon:
                                  o.id == _codeLangDropdownValue(block)
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 20,
                                      color: scheme.primary,
                                    )
                                  : null,
                              onPressed: () {
                                _onCodeLanguagePicked(
                                  page.id,
                                  block.id,
                                  index,
                                  o.id,
                                );
                              },
                              child: Text(o.label),
                            ),
                        ],
                        builder: (context, menuController, child) {
                          final id = _codeLangDropdownValue(block);
                          final label = _codeLangLabelForId(id);
                          final langIcon = codeLanguageIcon(id);
                          return Material(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.8,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                if (menuController.isOpen) {
                                  menuController.close();
                                } else {
                                  menuController.open();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      langIcon,
                                      size: 20,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        label,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 22,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CodeTheme(
                      data: folioCodeThemeData(theme),
                      child: ColoredBox(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.55,
                        ),
                        child: CodeField(
                          // flutter_code_editor no actualiza el FocusNode interno en didUpdateWidget;
                          // sin esta clave, al resincronizar controladores se reutiliza el State con un nodo ya disposed.
                          key: ObjectKey(focus),
                          controller: codeCtrl,
                          focusNode: focus,
                          minLines: 3,
                          maxLines: null,
                          wrap: true,
                          textStyle: _styleFor('code', theme.textTheme),
                          decoration: const BoxDecoration(),
                          padding: const EdgeInsets.all(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'divider') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            const Expanded(child: Divider()),
          ],
        ),
      );
    }

    if (block.type == 'file') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                height: 260,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: FutureBuilder<File?>(
                  future: _resolveBlockUrlFileCached(block.url),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context).fileResolveError,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _pickFileForBlock(page.id, block.id),
                            icon: const Icon(Icons.attach_file_rounded),
                            label: Text(
                              AppLocalizations.of(context).replaceFile,
                            ),
                          ),
                        ],
                      );
                    }
                    final file = snap.data;
                    if (file == null) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if ((block.url ?? '').trim().isNotEmpty)
                            Text(
                              AppLocalizations.of(context).fileMissing,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.error,
                              ),
                            ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _pickFileForBlock(page.id, block.id),
                            icon: const Icon(Icons.attach_file_rounded),
                            label: Text(
                              (block.url ?? '').trim().isEmpty
                                  ? AppLocalizations.of(context).chooseFile
                                  : AppLocalizations.of(context).replaceFile,
                            ),
                          ),
                          if ((block.url ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () =>
                                  _clearBlockUrl(page.id, block.id),
                              child: Text(
                                AppLocalizations.of(context).removeFile,
                              ),
                            ),
                          ],
                        ],
                      );
                    }
                    return FolioFilePreviewCard(
                      file: file,
                      theme: theme,
                      scheme: scheme,
                      onOpenExternal: () => _openBlockUrlExternal(block.url),
                      onReplace: () => _pickFileForBlock(page.id, block.id),
                      onClear: () => _clearBlockUrl(page.id, block.id),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'video') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: FutureBuilder<File?>(
                  future: _resolveBlockUrlFileCached(block.url),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context).videoResolveError,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: () =>
                                _pickVideoForBlock(page.id, block.id),
                            child: Text(
                              AppLocalizations.of(context).replaceVideo,
                            ),
                          ),
                        ],
                      );
                    }
                    final file = snap.data;
                    if (file == null) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if ((block.url ?? '').trim().isNotEmpty)
                            Text(
                              AppLocalizations.of(context).videoMissing,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.error,
                              ),
                            ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: () =>
                                _pickVideoForBlock(page.id, block.id),
                            child: Text(
                              (block.url ?? '').trim().isEmpty
                                  ? AppLocalizations.of(context).chooseVideo
                                  : AppLocalizations.of(context).replaceVideo,
                            ),
                          ),
                          if ((block.url ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () =>
                                  _clearBlockUrl(page.id, block.id),
                              child: Text(
                                AppLocalizations.of(context).removeVideo,
                              ),
                            ),
                          ],
                        ],
                      );
                    }
                    return FolioEmbeddedVideoPlayer(
                      key: ValueKey(file.path),
                      file: file,
                      scheme: scheme,
                      onOpenExternal: () => _openBlockUrlExternal(block.url),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isParagraph = block.type == 'paragraph';
    final isListLine = block.type == 'todo' || block.type == 'bullet';

    const slashTypes = {
      'paragraph',
      'h1',
      'h2',
      'h3',
      'bullet',
      'todo',
      'quote',
      'callout',
    };
    final allowsSlash = slashTypes.contains(block.type);
    final String? slashTail = allowsSlash
        ? _slashFilterFromBlockText(ctrl.text)
        : null;
    final showSlashMenu = slashTail != null && _slashBlockId == block.id;
    final slashItems = showSlashMenu
        ? _catalogFiltered(slashTail)
        : const <BlockTypeDef>[];
    final slashPanelMaxH = math.min(
      192.0,
      math.max(100.0, MediaQuery.sizeOf(context).height * 0.25),
    );

    final showInlinePreview =
        allowsSlash && !focus.hasFocus && ctrl.text.trim().isNotEmpty;

    var currentStyle = style;
    if (block.type == 'quote') {
      currentStyle = currentStyle.copyWith(
        fontStyle: FontStyle.italic,
        fontSize: currentStyle.fontSize! * 1.05,
        color: scheme.onSurface.withValues(alpha: 0.8),
      );
    }

    final field = TextField(
      controller: ctrl,
      focusNode: focus,
      maxLines: null,
      minLines: isParagraph ? 2 : 1,
      style: showInlinePreview
          ? currentStyle.copyWith(
              color: Colors.transparent,
              decoration: TextDecoration.none,
            )
          : currentStyle,
      textAlignVertical: isParagraph
          ? TextAlignVertical.top
          : TextAlignVertical.center,
      decoration: isListLine
          ? InputDecoration.collapsed(
              hintText: block.type == 'todo' ? 'Tarea…' : '',
            )
          : InputDecoration(
              border: InputBorder.none,
              isDense: true,
              filled: false,
              hintText: isParagraph
                  ? 'Escribe…  /  para tipos de bloque'
                  : null,
              contentPadding: EdgeInsets.zero,
            ),
    );

    final mdSheet = folioMarkdownStyleSheet(context, style, scheme);
    final stackedField = Stack(
      children: [
        field,
        if (showInlinePreview)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => focus.requestFocus(),
              child: Align(
                alignment: isParagraph
                    ? AlignmentDirectional.topStart
                    : AlignmentDirectional.centerStart,
                child: FolioMarkdownPreview(
                  data: ctrl.text,
                  styleSheet: mdSheet,
                ),
              ),
            ),
          ),
      ],
    );

    Widget textContainer = stackedField;
    if (block.type == 'quote') {
      textContainer = Container(
        padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: scheme.outlineVariant, width: 4),
          ),
        ),
        child: stackedField,
      );
    } else if (block.type == 'callout') {
      textContainer = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primaryContainer),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () async {
                    final emoji = await _pickEmoji(context);
                    if (emoji != null) {
                      _s.updateBlockIcon(page.id, block.id, emoji);
                    }
                  },
                  child: Text(
                    block.icon ?? '💡',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ),
            Expanded(child: stackedField),
          ],
        ),
      );
    }

    final editorSlot = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (allowsSlash && _formatStickyBlockId == block.id) ...[
          FolioFormatToolbar(
            controller: ctrl,
            colorScheme: scheme,
            textFocusNode: focus,
          ),
          const SizedBox(height: 6),
        ],
        textContainer,
      ],
    );

    final Widget textSlot;
    if (showSlashMenu) {
      final tail = slashTail;
      textSlot = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          editorSlot,
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Material(
              type: MaterialType.canvas,
              elevation: 12,
              shadowColor: scheme.shadow.withValues(alpha: 0.25),
              color: scheme.surfaceContainerHigh,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: slashPanelMaxH,
                  minHeight: slashItems.isEmpty ? 48 : 72,
                ),
                child: slashItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Sin coincidencias',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _slashListScrollController,
                        interactive: false,
                        thumbVisibility: true,
                        thickness: 3,
                        radius: const Radius.circular(3),
                        child: _InlineSlashList(
                          scrollController: _slashListScrollController,
                          theme: theme,
                          scheme: scheme,
                          items: slashItems,
                          showSections: tail.trim().isEmpty,
                          onPick: _applyInlineSlashChoice,
                        ),
                      ),
              ),
            ),
          ),
        ],
      );
    } else {
      textSlot = editorSlot;
    }

    final row = Row(
      crossAxisAlignment: isParagraph
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        _blockMenuSlot(showActions: showActions, menu: menu),
        dragHandle,
        marker,
        Expanded(child: textSlot),
      ],
    );

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
      child: row,
    );
  }
}

class _DragHandleWidget extends StatefulWidget {
  final Color iconColor;
  const _DragHandleWidget({required this.iconColor});

  @override
  State<_DragHandleWidget> createState() => _DragHandleWidgetState();
}

class _DragHandleWidgetState extends State<_DragHandleWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hovered
              ? Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          Icons.drag_indicator,
          size: 18,
          color: widget.iconColor.withValues(alpha: _hovered ? 1.0 : 0.6),
        ),
      ),
    );
  }
}

/// Lista compacta del comando `/` (viewport de altura fija + scroll real).
class _InlineSlashList extends StatelessWidget {
  const _InlineSlashList({
    required this.scrollController,
    required this.theme,
    required this.scheme,
    required this.items,
    required this.showSections,
    required this.onPick,
  });

  final ScrollController scrollController;
  final ThemeData theme;
  final ColorScheme scheme;
  final List<BlockTypeDef> items;
  final bool showSections;
  final void Function(String typeKey) onPick;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    BlockTypeSection? prev;
    for (final def in items) {
      if (showSections && prev != def.section) {
        prev = def.section;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              blockSectionTitle(def.section),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onPick(def.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        def.icon,
                        size: 16,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: showSections
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  def.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    height: 1.15,
                                  ),
                                ),
                                Text(
                                  def.hint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 11,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              def.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                height: 1.2,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      primary: false,
      physics: const ClampingScrollPhysics(),
      children: children,
    );
  }
}

class BlockTypePickerSheet extends StatefulWidget {
  const BlockTypePickerSheet({required this.catalog});

  final List<BlockTypeDef> catalog;

  @override
  State<BlockTypePickerSheet> createState() => BlockTypePickerSheetState();
}

class BlockTypePickerSheetState extends State<BlockTypePickerSheet> {
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

  List<BlockTypeDef> _filtered() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.catalog;
    return widget.catalog.where((d) {
      return d.key.contains(q) ||
          d.label.toLowerCase().contains(q) ||
          d.hint.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filtered = _filtered();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: scheme.surface,
          elevation: 2,
          shadowColor: scheme.shadow.withValues(alpha: 0.2),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tipos de bloque',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Elige cómo se verá este bloque',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _filter,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(
                        context,
                      ).searchByNameOrShortcut,
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.42,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'Nada coincide con tu búsqueda',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
                          children: _sectionedTiles(
                            context,
                            theme,
                            scheme,
                            filtered,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _sectionedTiles(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    List<BlockTypeDef> items,
  ) {
    final out = <Widget>[];
    BlockTypeSection? prev;
    for (final def in items) {
      if (prev != def.section) {
        prev = def.section;
        out.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Text(
              blockSectionTitle(def.section),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
      }
      out.add(_BlockTypeTile(def: def, scheme: scheme, theme: theme));
    }
    return out;
  }
}

class _BlockTypeTile extends StatelessWidget {
  const _BlockTypeTile({
    required this.def,
    required this.scheme,
    required this.theme,
  });

  final BlockTypeDef def;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pop(context, def.key),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    def.icon,
                    color: scheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        def.hint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
