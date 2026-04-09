import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, setEquals;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../app/app_settings.dart';
import '../../../app/widgets/folio_icon_picker.dart';
import '../../../app/widgets/folio_icon_token_view.dart';
import '../../../data/folio_internal_link.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../data/vault_paths.dart';
import '../../../app/ui_tokens.dart';
import '../../../models/block.dart';
import '../../../models/folio_template_button_data.dart';
import '../../../models/folio_database_data.dart';
import '../../../models/folio_page.dart';
import '../../../models/folio_table_data.dart';
import '../../../services/run2doc/run2doc_markdown_codec.dart';
import '../../../session/vault_session.dart';
import 'code_block_languages.dart';
import 'block_editor_support_widgets.dart';
import 'block_type_catalog.dart';
import 'database_block_editor.dart';
import 'folio_mermaid_preview.dart';
import 'file_video_previews.dart';
import 'folio_text_format.dart';
import 'folio_embed_webview.dart';
import 'folio_youtube.dart';
import 'link_title_fetch.dart';
import 'paste_url_sheet.dart';
import 'folio_special_block_widgets.dart';
import 'table_block_editor.dart';
import 'ai_typewriter_message.dart';

/// `null` si el texto del bloque no es comando `/…`; si no, filtro tras la `/` (puede ser vacío).
String? _slashFilterFromBlockText(String text) {
  if (!text.startsWith('/')) return null;
  if (text.contains('\n')) return null;
  final tail = text.substring(1);
  if (tail.contains(' ')) return null;
  return tail;
}

int? _mentionTriggerStartFromSelection(String text, TextSelection selection) {
  if (!selection.isValid || !selection.isCollapsed) return null;
  final caret = selection.baseOffset;
  if (caret <= 0 || caret > text.length) return null;
  var start = caret - 1;
  while (start >= 0) {
    final code = text.codeUnitAt(start);
    if (code == 0x20 || code == 0x0A || code == 0x0D || code == 0x09) {
      break;
    }
    start--;
  }
  start += 1;
  if (start >= caret) return null;
  if (text.codeUnitAt(start) != 0x40 /* @ */ ) return null;
  final tail = text.substring(start + 1, caret);
  if (tail.contains(RegExp(r'[\[\]\(\)]'))) return null;
  return start;
}

String? _mentionFilterFromSelection(String text, TextSelection selection) {
  final start = _mentionTriggerStartFromSelection(text, selection);
  if (start == null) return null;
  final caret = selection.baseOffset;
  return text.substring(start + 1, caret);
}

bool _usesCodeControllerForBlockType(String type) =>
    type == 'code' || type == 'mermaid' || type == 'equation';

List<BlockTypeDef> _catalogFiltered(String q) {
  return filterBlockTypeCatalog(q);
}

enum _CalloutTone { neutral, info, success, warning, danger }

_CalloutTone _calloutToneForIcon(String? icon) {
  switch (icon) {
    case '💡':
    case 'ℹ️':
      return _CalloutTone.info;
    case '✅':
    case '🎉':
    case '🟢':
      return _CalloutTone.success;
    case '⚠️':
    case '🟡':
      return _CalloutTone.warning;
    case '🚨':
    case '⛔':
    case '❗':
    case '🔴':
      return _CalloutTone.danger;
    default:
      return _CalloutTone.neutral;
  }
}

Color _calloutBackgroundForTone(ColorScheme scheme, _CalloutTone tone) {
  switch (tone) {
    case _CalloutTone.info:
      return scheme.primaryContainer.withValues(alpha: 0.26);
    case _CalloutTone.success:
      return scheme.tertiaryContainer.withValues(alpha: 0.26);
    case _CalloutTone.warning:
      return scheme.secondaryContainer.withValues(alpha: 0.34);
    case _CalloutTone.danger:
      return scheme.errorContainer.withValues(alpha: 0.3);
    case _CalloutTone.neutral:
      return scheme.surfaceContainerHighest.withValues(alpha: 0.5);
  }
}

Color _calloutBorderForTone(ColorScheme scheme, _CalloutTone tone) {
  switch (tone) {
    case _CalloutTone.info:
      return scheme.primary.withValues(alpha: 0.45);
    case _CalloutTone.success:
      return scheme.tertiary.withValues(alpha: 0.45);
    case _CalloutTone.warning:
      return scheme.secondary.withValues(alpha: 0.5);
    case _CalloutTone.danger:
      return scheme.error.withValues(alpha: 0.5);
    case _CalloutTone.neutral:
      return scheme.outlineVariant.withValues(alpha: 0.5);
  }
}

Color _calloutChipForTone(ColorScheme scheme, _CalloutTone tone) {
  switch (tone) {
    case _CalloutTone.info:
      return scheme.primaryContainer.withValues(alpha: 0.75);
    case _CalloutTone.success:
      return scheme.tertiaryContainer.withValues(alpha: 0.75);
    case _CalloutTone.warning:
      return scheme.secondaryContainer.withValues(alpha: 0.85);
    case _CalloutTone.danger:
      return scheme.errorContainer.withValues(alpha: 0.85);
    case _CalloutTone.neutral:
      return scheme.surfaceContainerHighest.withValues(alpha: 0.85);
  }
}

const _stylableBlockTypes = <String>{
  'paragraph',
  'h1',
  'h2',
  'h3',
  'bullet',
  'numbered',
  'todo',
  'quote',
  'callout',
};

const _blockFontScaleOptions = <double>[0.9, 1.0, 1.15, 1.3];
const _blockTextColorRoles = <String?>[
  null,
  'subtle',
  'primary',
  'secondary',
  'tertiary',
  'error',
];
const _blockBackgroundRoles = <String?>[
  null,
  'surface',
  'primary',
  'secondary',
  'tertiary',
  'error',
];

const _inlineSlashActionCatalog = <BlockTypeDef>[
  BlockTypeDef(
    key: 'cmd_duplicate_prev',
    label: 'Duplicar bloque anterior',
    hint: 'Clona el bloque inmediatamente anterior',
    icon: Icons.copy_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'cmd_insert_date',
    label: 'Insertar fecha',
    hint: 'Escribe la fecha actual',
    icon: Icons.event_rounded,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'cmd_mention_page',
    label: 'Mencionar pagina',
    hint: 'Inserta enlace interno a una pagina',
    icon: Icons.insert_link_outlined,
    section: BlockTypeSection.advanced,
  ),
  BlockTypeDef(
    key: 'cmd_turn_into',
    label: 'Convertir bloque',
    hint: 'Elegir tipo de bloque con picker',
    icon: Icons.swap_horiz_rounded,
    section: BlockTypeSection.advanced,
  ),
];

class BlockEditor extends StatefulWidget {
  const BlockEditor({
    super.key,
    required this.session,
    required this.appSettings,
    this.readOnlyMode = false,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final bool readOnlyMode;

  @override
  State<BlockEditor> createState() => BlockEditorState();
}

class BlockEditorState extends State<BlockEditor> {
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
  final Set<String> _selectedBlockIds = <String>{};
  String? _selectionAnchorBlockId;
  bool _dragSelectionActive = false;
  String? _dragSelectionOriginBlockId;
  Set<String> _dragSelectionBaseIds = <String>{};

  /// Evita quitar el botón ⋮ del árbol mientras el popup está abierto (el ratón sale del `MouseRegion`).
  String? _menuOpenBlockId;

  /// Bloques Mermaid cuyo código fuente se muestra explícitamente (menú ⋮ → Editar diagrama).
  final Set<String> _mermaidEditingSourceIds = {};
  final List<String> _controllerBlockIds = [];
  String? _slashBlockId;
  String? _slashPageId;
  int _slashSelectedIndex = 0;
  final Map<String, int> _slashRecentByType = {};
  final ScrollController _slashListScrollController = ScrollController();
  String? _mentionBlockId;
  String? _mentionPageId;
  int _mentionSelectedIndex = 0;
  final ScrollController _mentionListScrollController = ScrollController();
  final Map<String, Future<File?>> _resolvedFileFutureByUrl = {};
  final LayerLink _formatToolbarLayerLink = LayerLink();
  OverlayEntry? _formatToolbarOverlayEntry;
  String? _formatToolbarOverlayBlockId;

  /// Bloque de texto cuya barra de formato sigue visible aunque el foco se mueva al pulsarla (p. ej. ScrollView).
  String? _formatStickyBlockId;
  Timer? _formatStickyClearTimer;

  /// Anclas para [VaultSession.requestScrollToBlock] (TOC).
  final Map<String, GlobalKey> _blockScrollKeys = {};

  final ScrollController _blockListScrollController = ScrollController();
  String? _prevPageIdForBlockScroll;
  int? _prevBlockCountForScroll;
  final Map<String, bool> _tailTapTransientTouchedByBlockId = {};

  VaultSession get _s => widget.session;
  bool get readOnlyMode => widget.readOnlyMode;

  Future<void> _applyTypewriterToBlock({
    required String pageId,
    required String blockId,
    required String fullText,
  }) async {
    final normalized = fullText.replaceAll('\r\n', '\n');
    final total = normalized.characters.length;
    if (total == 0) {
      _s.updateBlockText(pageId, blockId, '');
      return;
    }
    // Evitar animaciones excesivamente largas.
    const tick = Duration(milliseconds: 30);
    final charsPerTick = total <= 400 ? 4 : (total <= 1200 ? 8 : 14);
    var visible = 0;
    while (mounted && visible < total) {
      visible = (visible + charsPerTick).clamp(0, total);
      final partial = normalized.characters.take(visible).toString();
      _s.updateBlockText(pageId, blockId, partial);
      await Future<void>.delayed(tick);
    }
    if (!mounted) return;
    _s.updateBlockText(pageId, blockId, normalized);
  }

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

  Widget _blockMediaWidthToolbar(
    FolioPage page,
    FolioBlock block,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => _nudgeImageWidth(page, block, -0.1),
            icon: const Icon(Icons.remove, size: 16),
            label: Text(l10n.blockSizeSmaller),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _nudgeImageWidth(page, block, 0.1),
            icon: const Icon(Icons.add, size: 16),
            label: Text(l10n.blockSizeLarger),
          ),
          OutlinedButton(
            onPressed: () => _s.setBlockImageWidth(page.id, block.id, 0.5),
            child: Text(l10n.blockSizeHalf),
          ),
          OutlinedButton(
            onPressed: () => _s.setBlockImageWidth(page.id, block.id, 0.75),
            child: Text(l10n.blockSizeThreeQuarter),
          ),
          OutlinedButton(
            onPressed: () => _s.setBlockImageWidth(page.id, block.id, 1.0),
            child: Text(l10n.blockSizeFull),
          ),
        ],
      ),
    );
  }

  static const _slashFormatTypes = {
    'paragraph',
    'h1',
    'h2',
    'h3',
    'bullet',
    'numbered',
    'todo',
    'toggle',
    'quote',
    'callout',
  };

  bool _hasExpandedSelectionForBlockId(String blockId) {
    final idx = _controllerBlockIds.indexWhere((x) => x == blockId);
    if (idx < 0 || idx >= _controllers.length) return false;
    final sel = _controllers[idx].selection;
    return sel.isValid && !sel.isCollapsed;
  }

  void _syncFormatStickyBlockId() {
    _formatStickyClearTimer?.cancel();
    _formatStickyClearTimer = null;
    final page = _s.selectedPage;
    if (page == null) {
      _formatStickyBlockId = null;
      _removeFormatToolbarOverlay();
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
          _removeFormatToolbarOverlay();
        }
        return;
      }
    }
    _formatStickyClearTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      if (!_focusNodes.any((n) => n.hasFocus)) {
        setState(() => _formatStickyBlockId = null);
        _removeFormatToolbarOverlay();
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
    _removeFormatToolbarOverlay();
    _slashListScrollController.dispose();
    _mentionListScrollController.dispose();
    _blockListScrollController.dispose();
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
    _slashSelectedIndex = 0;
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
    _slashSelectedIndex = 0;
    _slashRecentByType.update(typeKey, (v) => v + 1, ifAbsent: () => 1);

    if (typeKey.startsWith('cmd_')) {
      if (idx >= 0 && idx < _controllers.length) {
        final c = _controllers[idx];
        _ignoreShortcuts = true;
        c.value = const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
        _s.updateBlockText(pid, id, '');
        _ignoreShortcuts = false;
      }
      unawaited(_runInlineSlashAction(typeKey, pageId: pid, blockId: id));
      return;
    }

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

  Future<void> _runInlineSlashAction(
    String actionKey, {
    required String pageId,
    required String blockId,
  }) async {
    final page = _s.selectedPage;
    if (page == null || page.id != pageId) return;
    final blockIndex = page.blocks.indexWhere((b) => b.id == blockId);
    if (blockIndex < 0) return;

    if (actionKey == 'cmd_insert_date') {
      final date = DateFormat.yMMMd(
        Localizations.localeOf(context).toLanguageTag(),
      ).format(DateTime.now());
      _s.updateBlockText(pageId, blockId, date);
      final ci = _controllerBlockIds.indexWhere((x) => x == blockId);
      if (ci >= 0 && ci < _controllers.length) {
        _ignoreShortcuts = true;
        _controllers[ci].value = TextEditingValue(
          text: date,
          selection: TextSelection.collapsed(offset: date.length),
        );
        _ignoreShortcuts = false;
      }
      return;
    }

    if (actionKey == 'cmd_mention_page') {
      final picked = await _pickPageForChildBlock(context, excludeId: pageId);
      if (picked == null || !mounted) return;
      final pIndex = _s.pages.indexWhere((p) => p.id == picked);
      if (pIndex < 0) return;
      final title = _s.pages[pIndex].title.trim();
      final label = title.isEmpty ? '@pagina' : '@$title';
      final markdown = '[$label](${folioPageLinkUri(picked)})';
      _s.updateBlockText(pageId, blockId, markdown);
      final ci = _controllerBlockIds.indexWhere((x) => x == blockId);
      if (ci >= 0 && ci < _controllers.length) {
        _ignoreShortcuts = true;
        _controllers[ci].value = TextEditingValue(
          text: markdown,
          selection: TextSelection.collapsed(offset: markdown.length),
        );
        _ignoreShortcuts = false;
      }
      return;
    }

    if (actionKey == 'cmd_duplicate_prev') {
      if (blockIndex <= 0) return;
      final prev = page.blocks[blockIndex - 1];
      _duplicateSelectedBlocks(page, [prev.id]);
      return;
    }

    if (actionKey == 'cmd_turn_into') {
      final choice = await _openBlockTypePicker(context);
      if (choice == null || choice.startsWith('cmd_')) return;
      _s.changeBlockType(pageId, blockId, choice);
      return;
    }
  }

  void _dismissInlineMention() {
    _mentionBlockId = null;
    _mentionPageId = null;
    _mentionSelectedIndex = 0;
    if (mounted) setState(() {});
  }

  void _removeFormatToolbarOverlay() {
    _formatToolbarOverlayEntry?.remove();
    _formatToolbarOverlayEntry = null;
    _formatToolbarOverlayBlockId = null;
  }

  void _showOrUpdateFormatToolbarOverlay({
    required String blockId,
    required TextEditingController controller,
    required FocusNode focusNode,
    required ColorScheme scheme,
    required FolioPage page,
    required FolioBlock block,
  }) {
    _formatToolbarOverlayEntry?.remove();
    _formatToolbarOverlayEntry = null;

    Widget buildToolbar() {
      return IgnorePointer(
        ignoring: false,
        child: CompositedTransformFollower(
          link: _formatToolbarLayerLink,
          showWhenUnlinked: true,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -8),
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FolioFormatToolbar(
                controller: controller,
                colorScheme: scheme,
                textFocusNode: focusNode,
                onOpenBlockAppearance: _blockSupportsAppearance(block)
                    ? () => unawaited(
                        _editBlockAppearance(page, block, focusNode: focusNode),
                      )
                    : null,
                onMentionPage: (ctx) => _toolbarMentionPage(ctx, controller),
                onInsertUserMention: () =>
                    _insertAtSelection(controller, '@usuario '),
                onInsertDateMention: () => _insertAtSelection(
                  controller,
                  '@${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(DateTime.now())} ',
                ),
                onInsertInlineMath: () =>
                    _insertAtSelection(controller, r'\( x \)'),
              ),
            ),
          ),
        ),
      );
    }

    _formatToolbarOverlayBlockId = blockId;
    _formatToolbarOverlayEntry = OverlayEntry(builder: (ctx) => buildToolbar());
    final overlay = Overlay.of(context, rootOverlay: true);
    overlay.insert(_formatToolbarOverlayEntry!);
  }

  List<FolioPage> _catalogFilteredForMention(String query) {
    final q = query.trim().toLowerCase();
    final items = _s.pages.where((p) {
      if (q.isEmpty) return true;
      final title = p.title.trim().toLowerCase();
      return title.contains(q);
    }).toList();

    int score(FolioPage p) {
      final t = p.title.trim().toLowerCase();
      if (q.isEmpty) return 0;
      if (t == q) return 0;
      if (t.startsWith(q)) return 1;
      return 2;
    }

    items.sort((a, b) {
      final sa = score(a);
      final sb = score(b);
      if (sa != sb) return sa.compareTo(sb);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return items;
  }

  void _applyInlineMentionChoice(String mentionedPageId) {
    final bid = _mentionBlockId;
    final pid = _mentionPageId;
    if (bid == null || pid == null) return;
    final idx = _controllerBlockIds.indexWhere((x) => x == bid);
    if (idx < 0 || idx >= _controllers.length) return;
    final c = _controllers[idx];
    final start = _mentionTriggerStartFromSelection(c.text, c.selection);
    if (start == null) {
      _dismissInlineMention();
      return;
    }
    final caret = c.selection.baseOffset;
    final pageIndex = _s.pages.indexWhere((p) => p.id == mentionedPageId);
    if (pageIndex < 0) {
      _dismissInlineMention();
      return;
    }
    final title = _s.pages[pageIndex].title.trim();
    final label = title.isEmpty ? '@pagina' : '@$title';
    final markdown = '[$label](${folioPageLinkUri(mentionedPageId)}) ';
    final next = c.text.replaceRange(start, caret, markdown);
    final offset = start + markdown.length;

    _ignoreShortcuts = true;
    c.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: offset),
    );
    _s.updateBlockText(pid, bid, next);
    _ignoreShortcuts = false;
    _dismissInlineMention();
  }

  List<BlockTypeDef> _catalogFilteredForSlash(String q) {
    final filtered = List<BlockTypeDef>.from(_catalogFiltered(q));
    final normalized = q.trim().toLowerCase();
    filtered.addAll(
      _inlineSlashActionCatalog.where((a) {
        if (normalized.isEmpty) return true;
        return a.key.contains(normalized) ||
            a.label.toLowerCase().contains(normalized) ||
            a.hint.toLowerCase().contains(normalized);
      }),
    );
    if (filtered.length < 2) return filtered;
    final catalogIndex = {
      for (var i = 0; i < blockTypeCatalog.length; i++)
        blockTypeCatalog[i].key: i,
      for (var i = 0; i < _inlineSlashActionCatalog.length; i++)
        _inlineSlashActionCatalog[i].key: blockTypeCatalog.length + i,
    };
    filtered.sort((a, b) {
      final aScore = _slashRecentByType[a.key] ?? 0;
      final bScore = _slashRecentByType[b.key] ?? 0;
      if (aScore != bScore) return bScore.compareTo(aScore);
      return (catalogIndex[a.key] ?? 0).compareTo(catalogIndex[b.key] ?? 0);
    });
    return filtered;
  }

  void _ensurePopupSelectionVisible(
    ScrollController controller,
    int index, {
    double itemExtent = 48,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      final pos = controller.position;
      final targetTop = index * itemExtent;
      final targetBottom = targetTop + itemExtent;
      final visibleTop = pos.pixels;
      final visibleBottom = pos.pixels + pos.viewportDimension;

      if (targetTop < visibleTop) {
        controller.animateTo(
          targetTop.clamp(0, pos.maxScrollExtent).toDouble(),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      } else if (targetBottom > visibleBottom) {
        final offset = (targetBottom - pos.viewportDimension)
            .clamp(0, pos.maxScrollExtent)
            .toDouble();
        controller.animateTo(
          offset,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
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
    _mentionBlockId = null;
    _mentionPageId = null;
    _mentionSelectedIndex = 0;
    _menuOpenBlockId = null;
    _mermaidEditingSourceIds.clear();
    _formatStickyClearTimer?.cancel();
    _formatStickyClearTimer = null;
    _formatStickyBlockId = null;
    _selectedBlockIds.clear();
    _selectionAnchorBlockId = null;
    _dragSelectionActive = false;
    _dragSelectionOriginBlockId = null;
    _dragSelectionBaseIds.clear();
  }

  bool _controllersMismatchPage(FolioPage page) {
    if (page.id != _boundPageId) return true;
    if (page.blocks.length != _controllers.length) return true;
    if (page.blocks.length != _controllerBlockIds.length) return true;
    for (var i = 0; i < page.blocks.length; i++) {
      if (page.blocks[i].id != _controllerBlockIds[i]) return true;
      final wantCode = _usesCodeControllerForBlockType(page.blocks[i].type);
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
      final wantCode = _usesCodeControllerForBlockType(b.type);
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
      _prevPageIdForBlockScroll = null;
      _prevBlockCountForScroll = null;
      _tailTapTransientTouchedByBlockId.clear();
      setState(() {});
      return;
    }
    if (_boundPageId != null && _boundPageId != page.id) {
      _selectedBlockIds.clear();
      _selectionAnchorBlockId = null;
    }
    _tailTapTransientTouchedByBlockId.removeWhere(
      (blockId, _) => !page.blocks.any((b) => b.id == blockId),
    );
    _selectedBlockIds.removeWhere(
      (blockId) => !page.blocks.any((b) => b.id == blockId),
    );
    if (_selectionAnchorBlockId != null &&
        !_selectedBlockIds.contains(_selectionAnchorBlockId)) {
      _selectionAnchorBlockId = _selectedBlockIds.isEmpty
          ? null
          : page.blocks
                .firstWhere((block) => _selectedBlockIds.contains(block.id))
                .id;
    }
    if (_controllersMismatchPage(page)) {
      if (_canReorderControllersOnly(page)) {
        _reorderControllersLikePage(page);
      } else {
        _syncControllers();
      }
    }
    final scrollId = _s.pendingScrollToBlockId;
    if (scrollId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pendingFocusBlockId = scrollId;
        setState(() {
          _selectedBlockIds
            ..clear()
            ..add(scrollId);
          _selectionAnchorBlockId = scrollId;
        });
        final ctx = _blockScrollKeys[scrollId]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: 0.12,
          );
        }
        final idx = _controllerBlockIds.indexOf(scrollId);
        if (idx >= 0 && idx < _focusNodes.length) {
          _focusNodes[idx].requestFocus();
        }
        _s.clearPendingScrollToBlock();
      });
    }

    final grew =
        page.id == _prevPageIdForBlockScroll &&
        _prevBlockCountForScroll != null &&
        page.blocks.length > _prevBlockCountForScroll!;
    _prevPageIdForBlockScroll = page.id;
    _prevBlockCountForScroll = page.blocks.length;
    if (scrollId == null && grew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        void scrollNow() {
          if (!mounted) return;
          if (!_blockListScrollController.hasClients) return;
          final pos = _blockListScrollController.position;
          _blockListScrollController.animateTo(
            pos.maxScrollExtent,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        }

        scrollNow();
        WidgetsBinding.instance.addPostFrameCallback((_) => scrollNow());
      });
    }
    setState(() {});
  }

  /// API pública para paneles externos (p. ej. índice lateral) que quieran
  /// desplazar el editor hasta un bloque concreto.
  void scrollToBlock(String blockId) {
    final page = _s.selectedPage;
    if (page == null || !page.blocks.any((b) => b.id == blockId)) return;
    _s.requestScrollToBlock(blockId);
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
    _blockScrollKeys.removeWhere(
      (id, _) => !page.blocks.any((b) => b.id == id),
    );

    for (final b in page.blocks) {
      final bid = b.id;
      final pid = page.id;
      final TextEditingController c = _usesCodeControllerForBlockType(b.type)
          ? CodeController(
              text: b.text,
              language: modeForLanguageId(
                (b.type == 'mermaid' || b.type == 'equation')
                    ? 'plaintext'
                    : b.codeLanguage,
              ),
            )
          : TextEditingController(text: b.text);

      void textListener() {
        if (!mounted) return;
        final p = _s.selectedPage;
        if (p == null || p.id != pid) return;
        _syncFormatStickyBlockId();
        final idx = p.blocks.indexWhere((x) => x.id == bid);
        if (idx < 0) return;
        if (_tailTapTransientTouchedByBlockId.containsKey(bid) &&
            c.text.isNotEmpty) {
          _tailTapTransientTouchedByBlockId[bid] = true;
        }
        const skipTextSync = {
          'toggle',
          'column_list',
          'template_button',
          'toc',
          'breadcrumb',
          'child_page',
        };
        if (skipTextSync.contains(p.blocks[idx].type)) return;
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
        if (!fn.hasFocus) {
          final touched = _tailTapTransientTouchedByBlockId[bid];
          if (touched != null) {
            if (!touched && c.text.trim().isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final pNow = _s.selectedPage;
                if (pNow == null || pNow.id != pid) return;
                final stillExists = pNow.blocks.any((x) => x.id == bid);
                if (!stillExists) {
                  _tailTapTransientTouchedByBlockId.remove(bid);
                  return;
                }
                final blockIndex = _controllerBlockIds.indexOf(bid);
                if (blockIndex >= 0 &&
                    blockIndex < _focusNodes.length &&
                    _focusNodes[blockIndex].hasFocus) {
                  return;
                }
                _tailTapTransientTouchedByBlockId.remove(bid);
                _s.removeBlockIfMultiple(pid, bid);
              });
            } else {
              _tailTapTransientTouchedByBlockId.remove(bid);
            }
          }
        }
        final pM = _s.selectedPage;
        if (pM != null) {
          final mi = pM.blocks.indexWhere((x) => x.id == bid);
          if (mi >= 0 &&
              pM.blocks[mi].type == 'mermaid' &&
              !fn.hasFocus &&
              pM.blocks[mi].text.trim().isNotEmpty) {
            _mermaidEditingSourceIds.remove(bid);
          }
        }
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
        final mentionBid = _mentionBlockId;
        if (mentionBid != null) {
          final mentionIdx = _controllerBlockIds.indexWhere(
            (x) => x == mentionBid,
          );
          if (mentionIdx >= 0 && !_focusNodes[mentionIdx].hasFocus) {
            final otherBlockFocused = _focusNodes.asMap().entries.any(
              (e) => e.key != mentionIdx && e.value.hasFocus,
            );
            if (otherBlockFocused) {
              _dismissInlineMention();
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
    if ((event.logicalKey == LogicalKeyboardKey.keyZ) &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _s.redoPageEdits(pageId: page.id);
      } else {
        _s.undoPageEdits(pageId: page.id);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyY &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _s.redoPageEdits(pageId: page.id);
      return KeyEventResult.handled;
    }

    final slashFilter = _slashBlockId == blockId
        ? _slashFilterFromBlockText(ctrl.text)
        : null;
    if (slashFilter != null) {
      final slashItems = _catalogFilteredForSlash(slashFilter);
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (slashItems.isEmpty) return KeyEventResult.handled;
        setState(() {
          _slashSelectedIndex = (_slashSelectedIndex + 1).clamp(
            0,
            slashItems.length - 1,
          );
        });
        _ensurePopupSelectionVisible(
          _slashListScrollController,
          _slashSelectedIndex,
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (slashItems.isEmpty) return KeyEventResult.handled;
        setState(() {
          _slashSelectedIndex = (_slashSelectedIndex - 1).clamp(
            0,
            slashItems.length - 1,
          );
        });
        _ensurePopupSelectionVisible(
          _slashListScrollController,
          _slashSelectedIndex,
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          slashItems.isNotEmpty) {
        final safe = _slashSelectedIndex.clamp(0, slashItems.length - 1);
        _applyInlineSlashChoice(slashItems[safe].key);
        return KeyEventResult.handled;
      }
    }

    final mentionFilter = _mentionBlockId == blockId
        ? _mentionFilterFromSelection(ctrl.text, ctrl.selection)
        : null;
    if (mentionFilter != null) {
      final mentionItems = _catalogFilteredForMention(mentionFilter);
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (mentionItems.isEmpty) return KeyEventResult.handled;
        setState(() {
          _mentionSelectedIndex = (_mentionSelectedIndex + 1).clamp(
            0,
            mentionItems.length - 1,
          );
        });
        _ensurePopupSelectionVisible(
          _mentionListScrollController,
          _mentionSelectedIndex,
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (mentionItems.isEmpty) return KeyEventResult.handled;
        setState(() {
          _mentionSelectedIndex = (_mentionSelectedIndex - 1).clamp(
            0,
            mentionItems.length - 1,
          );
        });
        _ensurePopupSelectionVisible(
          _mentionListScrollController,
          _mentionSelectedIndex,
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          mentionItems.isNotEmpty) {
        final safe = _mentionSelectedIndex.clamp(0, mentionItems.length - 1);
        _applyInlineMentionChoice(mentionItems[safe].id);
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _s.unindentBlock(page.id, blockId);
      } else {
        _s.indentBlock(page.id, blockId);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      final bt0 = page.blocks[index].type;
      const pasteTypes = {
        'paragraph',
        'h1',
        'h2',
        'h3',
        'bullet',
        'numbered',
        'todo',
        'toggle',
        'quote',
        'callout',
      };
      if (pasteTypes.contains(bt0)) {
        unawaited(_handleClipboardPaste(page, blockId, index, ctrl));
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.keyD &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      final b = page.blocks[index];
      _duplicateBlock(page, b, index);
      return KeyEventResult.handled;
    }

    final blockType = page.blocks[index].type;
    if ((blockType == 'code' ||
            blockType == 'mermaid' ||
            blockType == 'equation') &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      if (!widget.appSettings.enterCreatesNewBlock) {
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
        if (curType == 'bullet' || curType == 'todo' || curType == 'numbered') {
          _s.insertBlockAfter(
            pageId: page.id,
            afterBlockId: blockId,
            block: FolioBlock(
              id: '${page.id}_${_uuid.v4()}',
              type: curType,
              text: '',
              checked: curType == 'todo' ? false : null,
              depth: page.blocks[index].depth,
              appearance: page.blocks[index].appearance,
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
      if (_mentionBlockId == blockId) {
        _dismissInlineMention();
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

  String? _singleHttpUrlTrimmed(String raw) {
    final t = raw.trim();
    if (t.contains('\n') || t.contains('\r')) return null;
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    final u = Uri.tryParse(t);
    if (u == null || !u.hasAuthority) return null;
    return t;
  }

  void _insertAtSelection(TextEditingController ctrl, String insertion) {
    final sel = ctrl.selection;
    final text = ctrl.text;
    if (!sel.isValid) {
      final newText = text + insertion;
      _ignoreShortcuts = true;
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      _ignoreShortcuts = false;
      return;
    }
    var start = sel.start;
    var end = sel.end;
    if (start < 0 || end < 0) {
      final newText = text + insertion;
      _ignoreShortcuts = true;
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      _ignoreShortcuts = false;
      return;
    }
    if (start > end) {
      final x = start;
      start = end;
      end = x;
    }
    final newText = text.replaceRange(start, end, insertion);
    final newOff = (start + insertion.length).clamp(0, newText.length);
    _ignoreShortcuts = true;
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOff),
    );
    _ignoreShortcuts = false;
  }

  /// Returns true if [text] contains Markdown block-level syntax worth parsing.
  bool _containsMarkdownBlockSyntax(String text) {
    return text.split('\n').any((line) {
      final t = line.trimLeft();
      return t.startsWith('# ') ||
          t.startsWith('## ') ||
          t.startsWith('### ') ||
          t.startsWith('#### ') ||
          t.startsWith('- ') ||
          t.startsWith('* ') ||
          t.startsWith('> ') ||
          t.startsWith('```') ||
          t.startsWith('- [ ]') ||
          t.startsWith('- [x]') ||
          RegExp(r'^\d+\. ').hasMatch(t);
    });
  }

  void _pasteMarkdownAsBlocks(
    FolioPage page,
    String blockId,
    TextEditingController ctrl,
    String markdown,
  ) {
    final sel = ctrl.selection;
    final text = ctrl.text;
    final cursor = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final textBefore = text.substring(0, cursor);
    final textAfter = text.substring(cursor);

    final parsed = FolioMarkdownCodec.parseBlocks(markdown, pageId: page.id);
    final blocks = _s.cloneBlocksWithNewIds(page.id, parsed);

    if (blocks.isEmpty) {
      _insertAtSelection(ctrl, markdown);
      return;
    }

    _ignoreShortcuts = true;
    ctrl.value = TextEditingValue(
      text: textBefore,
      selection: TextSelection.collapsed(offset: textBefore.length),
    );
    _ignoreShortcuts = false;

    _s.pasteMarkdownBlocksAtCaret(
      pageId: page.id,
      blockId: blockId,
      textBefore: textBefore,
      pastedBlocks: blocks,
      textAfter: textAfter,
    );
  }

  Future<void> _handleClipboardPaste(
    FolioPage page,
    String blockId,
    int index,
    TextEditingController ctrl,
  ) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final raw = data?.text;
    if (raw == null) return;
    final url = _singleHttpUrlTrimmed(raw);
    if (url != null) {
      final mode = await showPasteUrlOptionsSheet(context);
      if (!mounted || mode == null) return;
      await _applyPasteUrlMode(page, blockId, index, ctrl, url, mode);
      return;
    }
    if (!mounted) return;
    if (raw.contains('\n') && _containsMarkdownBlockSyntax(raw)) {
      _pasteMarkdownAsBlocks(page, blockId, ctrl, raw);
      return;
    }
    _insertAtSelection(ctrl, raw);
  }

  Future<void> _applyPasteUrlMode(
    FolioPage page,
    String blockId,
    int index,
    TextEditingController ctrl,
    String url,
    FolioPasteUrlMode mode,
  ) async {
    switch (mode) {
      case FolioPasteUrlMode.markdownUrl:
        final uri = Uri.tryParse(url);
        final host = (uri != null && uri.host.isNotEmpty) ? uri.host : 'link';
        folioApplyLink(ctrl, host, url);
        break;
      case FolioPasteUrlMode.embed:
        _ignoreShortcuts = true;
        _s.changeBlockType(page.id, blockId, 'embed');
        _s.updateBlockUrl(page.id, blockId, url);
        _s.updateBlockText(page.id, blockId, '');
        if (index < _controllers.length) {
          _controllers[index].value = const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          );
        }
        _ignoreShortcuts = false;
        if (mounted) setState(() {});
        break;
      case FolioPasteUrlMode.bookmark:
        _ignoreShortcuts = true;
        _s.changeBlockType(page.id, blockId, 'bookmark');
        _s.updateBlockUrl(page.id, blockId, url);
        _s.updateBlockText(page.id, blockId, '');
        if (index < _controllers.length) {
          _controllers[index].value = const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          );
        }
        _ignoreShortcuts = false;
        unawaited(_refreshBookmarkTitleIfEmpty(page.id, blockId, url));
        if (mounted) setState(() {});
        break;
      case FolioPasteUrlMode.vaultMention:
        final title = await fetchLinkTitleForMention(url);
        if (!mounted) return;
        var label = title;
        if (folioYoutubeVideoIdFromUrl(url) != null) {
          label = '▶ $title';
        }
        folioApplyLink(ctrl, label, url);
        break;
    }
  }

  Future<void> _refreshBookmarkTitleIfEmpty(
    String pageId,
    String blockId,
    String url,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final title = await fetchWebPageTitle(uri);
    if (!mounted || title == null || title.isEmpty) return;
    final p = _s.selectedPage;
    if (p == null || p.id != pageId) return;
    final i = p.blocks.indexWhere((b) => b.id == blockId);
    if (i < 0) return;
    final b = p.blocks[i];
    if (b.type != 'bookmark') return;
    if (b.text.trim().isNotEmpty) return;
    _s.updateBlockText(pageId, blockId, title);
    final j = _controllerBlockIds.indexOf(blockId);
    if (j >= 0 && j < _controllers.length) {
      _ignoreShortcuts = true;
      _controllers[j].value = TextEditingValue(
        text: title,
        selection: TextSelection.collapsed(offset: title.length),
      );
      _ignoreShortcuts = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _editBookmarkUrlDialog(
    String pageId,
    String blockId,
    int index,
  ) async {
    final p = _s.selectedPage;
    if (p == null) return;
    FolioBlock? b;
    for (final x in p.blocks) {
      if (x.id == blockId) {
        b = x;
        break;
      }
    }
    if (b == null || b.type != 'bookmark') return;
    final c = TextEditingController(text: b.url ?? '');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context).urlLabel),
          content: TextField(
            controller: c,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).urlHint,
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context).insert),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final u = c.text.trim();
      if (u.isEmpty) return;
      _s.updateBlockUrl(pageId, blockId, u);
      unawaited(_refreshBookmarkTitleIfEmpty(pageId, blockId, u));
      if (mounted) setState(() {});
    } finally {
      final ctrl = c;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.dispose();
      });
    }
  }

  Future<void> _editEmbedUrlDialog(
    String pageId,
    String blockId,
    int index,
  ) async {
    final p = _s.selectedPage;
    if (p == null) return;
    FolioBlock? b;
    for (final x in p.blocks) {
      if (x.id == blockId) {
        b = x;
        break;
      }
    }
    if (b == null || b.type != 'embed') return;
    final c = TextEditingController(text: b.url ?? '');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context).urlLabel),
          content: TextField(
            controller: c,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).urlHint,
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context).insert),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final u = c.text.trim();
      if (u.isEmpty) return;
      _s.updateBlockUrl(pageId, blockId, u);
      if (mounted) setState(() {});
    } finally {
      final ctrl = c;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.dispose();
      });
    }
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
      'numbered',
      'todo',
      'toggle',
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
      if (_mentionBlockId == blockId) {
        _dismissInlineMention();
      }
      return;
    }

    final slashFilter = _slashFilterFromBlockText(text);
    if (slashFilter != null) {
      if (_mentionBlockId == blockId) {
        _dismissInlineMention();
      }
      final open = _slashBlockId != blockId;
      _slashPageId = pageId;
      _slashBlockId = blockId;
      final slashItems = _catalogFilteredForSlash(slashFilter);
      if (open) {
        _slashSelectedIndex = 0;
      } else if (slashItems.isNotEmpty) {
        _slashSelectedIndex = _slashSelectedIndex.clamp(
          0,
          slashItems.length - 1,
        );
      } else {
        _slashSelectedIndex = 0;
      }
      setState(() {});
      if (open) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_slashListScrollController.hasClients) {
            _slashListScrollController.jumpTo(0);
          }
        });
      }
      return;
    }
    if (_slashBlockId == blockId) {
      _dismissInlineSlash(clearTypedCommand: false);
    }

    final sel = index < _controllers.length
        ? _controllers[index].selection
        : const TextSelection.collapsed(offset: -1);
    final mentionFilter = _mentionFilterFromSelection(text, sel);
    if (mentionFilter != null) {
      final open = _mentionBlockId != blockId;
      _mentionPageId = pageId;
      _mentionBlockId = blockId;
      final mentionItems = _catalogFilteredForMention(mentionFilter);
      if (open) {
        _mentionSelectedIndex = 0;
      } else if (mentionItems.isNotEmpty) {
        _mentionSelectedIndex = _mentionSelectedIndex.clamp(
          0,
          mentionItems.length - 1,
        );
      } else {
        _mentionSelectedIndex = 0;
      }
      setState(() {});
      if (open) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_mentionListScrollController.hasClients) {
            _mentionListScrollController.jumpTo(0);
          }
        });
      }
    } else if (_mentionBlockId == blockId) {
      _dismissInlineMention();
    }
  }

  /// `#` / `##` solos (o solo con espacios): el markdown no pinta texto y el
  /// campo con color transparente parece “vacío”; no usar vista previa aún.
  static bool _isIncompleteAtxHeadingLine(String text) {
    if (text.contains('\n') || text.contains('\r')) return false;
    return RegExp(r'^#{1,6}\s*$').hasMatch(text.trim());
  }

  bool _tryMarkdownShortcut(
    String pageId,
    String blockId,
    String text,
    int index,
  ) {
    String? type;
    var replacement = '';

    // No convertir con `# ` / `## ` / `### ` + espacio: pierde el foco y
    // impide escribir “# Título” en la misma línea. Usa /h1 o pega “# Texto”.
    if (text == '- ' || text == '* ') {
      type = 'bullet';
    } else if (text == '[] ' || text == '[ ] ') {
      type = 'todo';
    } else if (text == '``` ') {
      type = 'code';
    } else if (!text.contains('\n') && !text.contains('\r')) {
      final m = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(text);
      if (m != null) {
        final n = m.group(1)!.length;
        final body = m.group(2)!.trim();
        if (body.isNotEmpty) {
          type = switch (n) {
            1 => 'h1',
            2 => 'h2',
            _ => 'h3',
          };
          replacement = body;
        }
      }
    }
    if (type == null) return false;

    _ignoreShortcuts = true;
    _s.changeBlockType(pageId, blockId, type);
    _s.updateBlockText(pageId, blockId, replacement);
    if (index < _controllers.length) {
      _controllers[index].value = TextEditingValue(
        text: replacement,
        selection: TextSelection.collapsed(offset: replacement.length),
      );
    }
    _ignoreShortcuts = false;

    if (mounted) {
      final i = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (i >= _focusNodes.length) return;
        _focusNodes[i].requestFocus();
        if (i < _controllers.length) {
          final len = _controllers[i].text.length;
          _controllers[i].selection = TextSelection.collapsed(offset: len);
        }
      });
    }
    return true;
  }

  Future<String?> _openBlockTypePicker(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(
        context,
      ).colorScheme.scrim.withValues(alpha: FolioAlpha.scrim),
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

  bool _blockSupportsAppearance(FolioBlock block) {
    return _stylableBlockTypes.contains(block.type);
  }

  FolioBlockAppearance _blockAppearanceFor(FolioBlock block) {
    return FolioBlockAppearance.normalizeOrNull(block.appearance) ??
        const FolioBlockAppearance();
  }

  Color? _blockTextColorFor(ColorScheme scheme, String? role) {
    switch (role) {
      case 'subtle':
        return scheme.onSurfaceVariant;
      case 'primary':
        return scheme.primary;
      case 'secondary':
        return scheme.secondary;
      case 'tertiary':
        return scheme.tertiary;
      case 'error':
        return scheme.error;
      default:
        return null;
    }
  }

  Color? _blockBackgroundColorFor(ColorScheme scheme, String? role) {
    switch (role) {
      case 'surface':
        return scheme.surfaceContainerHigh.withValues(alpha: 0.72);
      case 'primary':
        return scheme.primaryContainer.withValues(alpha: 0.62);
      case 'secondary':
        return scheme.secondaryContainer.withValues(alpha: 0.62);
      case 'tertiary':
        return scheme.tertiaryContainer.withValues(alpha: 0.62);
      case 'error':
        return scheme.errorContainer.withValues(alpha: 0.7);
      default:
        return null;
    }
  }

  Color _blockBackgroundBorderColorFor(ColorScheme scheme, String? role) {
    switch (role) {
      case 'primary':
        return scheme.primary.withValues(alpha: 0.38);
      case 'secondary':
        return scheme.secondary.withValues(alpha: 0.38);
      case 'tertiary':
        return scheme.tertiary.withValues(alpha: 0.38);
      case 'error':
        return scheme.error.withValues(alpha: 0.42);
      case 'surface':
      default:
        return scheme.outlineVariant.withValues(alpha: 0.45);
    }
  }

  String _blockTextColorLabel(String? role) {
    switch (role) {
      case 'subtle':
        return 'Suave';
      case 'primary':
        return 'Primario';
      case 'secondary':
        return 'Secundario';
      case 'tertiary':
        return 'Acento';
      case 'error':
        return 'Error';
      default:
        return 'Tema';
    }
  }

  String _blockBackgroundLabel(String? role) {
    switch (role) {
      case 'surface':
        return 'Sutil';
      case 'primary':
        return 'Primario';
      case 'secondary':
        return 'Secundario';
      case 'tertiary':
        return 'Acento';
      case 'error':
        return 'Error';
      default:
        return 'Sin fondo';
    }
  }

  String _blockFontScaleLabel(double scale) {
    if (scale <= 0.9) return 'S';
    if (scale >= 1.3) return 'XL';
    if (scale > 1.0) return 'L';
    return 'M';
  }

  TextStyle _applyBlockAppearanceToTextStyle(
    TextStyle style,
    ColorScheme scheme,
    FolioBlock block,
  ) {
    final appearance = _blockAppearanceFor(block);
    var next = style;
    final baseSize = style.fontSize;
    if (baseSize != null) {
      next = next.copyWith(fontSize: baseSize * appearance.fontScale);
    }
    final color = _blockTextColorFor(scheme, appearance.textColorRole);
    if (color != null) {
      next = next.copyWith(color: color);
    }
    return next;
  }

  Future<void> _editBlockAppearance(
    FolioPage page,
    FolioBlock block, {
    FocusNode? focusNode,
  }) async {
    final result = await _openBlockAppearanceSheet(context, block);
    if (!mounted || result == null || !result.applied) return;
    _s.setBlockAppearance(page.id, block.id, result.appearance);
    if (mounted) setState(() {});
    focusNode?.requestFocus();
  }

  Future<({bool applied, FolioBlockAppearance? appearance})?>
  _openBlockAppearanceSheet(BuildContext context, FolioBlock block) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    var draft = _blockAppearanceFor(block);

    return showModalBottomSheet<
      ({bool applied, FolioBlockAppearance? appearance})
    >(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: scheme.scrim.withValues(alpha: 0.4),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Widget appearanceChip({
              required String label,
              required bool selected,
              required VoidCallback onTap,
              required Color swatch,
            }) {
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                ),
                selected: selected,
                onSelected: (_) => onTap(),
              );
            }

            final previewBlock = block.copyWith(appearance: draft);
            final previewStyle = _applyBlockAppearanceToTextStyle(
              _styleFor(previewBlock.type, theme.textTheme),
              scheme,
              previewBlock,
            );
            final previewBackground = _blockBackgroundColorFor(
              scheme,
              draft.backgroundRole,
            );
            final previewBorder = _blockBackgroundBorderColorFor(
              scheme,
              draft.backgroundRole,
            );

            return Material(
              color: scheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          color: scheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Apariencia del bloque',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Personaliza tamano, color del texto y fondo para este bloque.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Tamano',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final scale in _blockFontScaleOptions)
                          ChoiceChip(
                            label: Text(_blockFontScaleLabel(scale)),
                            selected: (draft.fontScale - scale).abs() < 0.001,
                            onSelected: (_) {
                              setModalState(() {
                                draft = FolioBlockAppearance(
                                  textColorRole: draft.textColorRole,
                                  backgroundRole: draft.backgroundRole,
                                  fontScale: scale,
                                );
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Color del texto',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final role in _blockTextColorRoles)
                          appearanceChip(
                            label: _blockTextColorLabel(role),
                            selected: draft.textColorRole == role,
                            onTap: () {
                              setModalState(() {
                                draft = FolioBlockAppearance(
                                  textColorRole: role,
                                  backgroundRole: draft.backgroundRole,
                                  fontScale: draft.fontScale,
                                );
                              });
                            },
                            swatch:
                                _blockTextColorFor(scheme, role) ??
                                scheme.onSurface,
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Fondo',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final role in _blockBackgroundRoles)
                          appearanceChip(
                            label: _blockBackgroundLabel(role),
                            selected: draft.backgroundRole == role,
                            onTap: () {
                              setModalState(() {
                                draft = FolioBlockAppearance(
                                  textColorRole: draft.textColorRole,
                                  backgroundRole: role,
                                  fontScale: draft.fontScale,
                                );
                              });
                            },
                            swatch:
                                _blockBackgroundColorFor(scheme, role) ??
                                scheme.surfaceContainerHighest,
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Vista previa',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: previewBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: previewBorder),
                      ),
                      child: Text(
                        block.text.trim().isEmpty
                            ? 'Asi se vera este bloque.'
                            : block.text.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: previewStyle,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              draft = const FolioBlockAppearance();
                            });
                          },
                          child: const Text('Restablecer'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx, (
                              applied: true,
                              appearance: FolioBlockAppearance.normalizeOrNull(
                                draft,
                              ),
                            ));
                          },
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
    if (FolioAdaptive.isAndroidDesktopLikeWidth(
      MediaQuery.sizeOf(context).width,
    )) {
      return true;
    }
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

  Future<void> _pickAudioForBlock(String pageId, String blockId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
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

  Future<void> _toolbarMentionPage(
    BuildContext ctx,
    TextEditingController ctrl,
  ) async {
    final cur = _s.selectedPage;
    final pid = await _pickPageForChildBlock(ctx, excludeId: cur?.id ?? '');
    if (pid == null || !mounted) return;
    final p = _s.pages.firstWhere((e) => e.id == pid);
    folioApplyLink(ctrl, p.title, folioPageLinkUri(pid));
  }

  Future<String?> _pickPageForChildBlock(
    BuildContext context, {
    required String excludeId,
  }) {
    final pages = _s.pages.where((p) => p.id != excludeId).toList();
    if (pages.isEmpty) return Future.value(null);
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            for (final p in pages)
              ListTile(
                title: Text(p.title),
                onTap: () => Navigator.pop(ctx, p.id),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTemplateButtonLabel(String pageId, FolioBlock block) async {
    final data =
        FolioTemplateButtonData.tryParse(block.text) ??
        FolioTemplateButtonData.defaultNew();
    final labelCtrl = TextEditingController(text: data.label);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Etiqueta del botón plantilla'),
        content: TextField(
          controller: labelCtrl,
          decoration: const InputDecoration(labelText: 'Texto del botón'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final next = FolioTemplateButtonData(
        label: labelCtrl.text.trim().isEmpty
            ? 'Plantilla'
            : labelCtrl.text.trim(),
        blocks: data.blocks,
      );
      _s.updateBlockText(pageId, block.id, next.encode());
      setState(() {});
    }
    labelCtrl.dispose();
  }

  Future<void> _openBlockUrlExternal(String? rawUrl) async {
    final raw = rawUrl?.trim();
    if (raw == null || raw.isEmpty) return;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final u = Uri.tryParse(raw);
      if (u != null && await canLaunchUrl(u)) {
        await launchUrl(u, mode: LaunchMode.externalApplication);
      }
      return;
    }
    final file = await _resolveBlockUrlFile(rawUrl);
    if (file == null) return;
    await launchUrl(Uri.file(file.path));
  }

  Future<String?> _pickEmoji(BuildContext context) async {
    return showFolioIconPicker(
      context: context,
      appSettings: widget.appSettings,
      title: _t('Icono del callout', 'Callout icon'),
      helperText: _t(
        'Selecciona un icono para cambiar el tono visual del bloque destacado.',
        'Select an icon to change the visual tone of the callout block.',
      ),
      fallbackText: '💡',
      quickIcons: const ['💡', '✅', '⚠️', '🚨', 'ℹ️', '📌', '🧠', '🚀'],
      customInputLabel: _t('Emoji personalizado', 'Custom emoji'),
      cancelLabel: AppLocalizations.of(context).cancel,
      saveLabel: AppLocalizations.of(context).save,
      removeLabel: _t('Quitar', 'Remove'),
      quickTabLabel: _t('Rapidos', 'Quick'),
      importedTabLabel: _t('Importados', 'Imported'),
      allEmojiTabLabel: _t('Todos', 'All'),
      emptyImportedLabel: _t(
        'Todavia no has importado iconos en Ajustes.',
        'You have not imported icons in Settings yet.',
      ),
    );
  }

  String _t(String es, String en) {
    final isEs = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('es');
    return isEs ? es : en;
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
              _blockMediaWidthToolbar(page, block, Theme.of(context)),
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

  void _addBlock(String pageId, {bool transientFromTailTap = false}) {
    final page = _s.selectedPage;
    if (page == null || page.blocks.isEmpty) return;
    final blockId = '${pageId}_${_uuid.v4()}';
    _pendingFocusIndex = page.blocks.length;
    _pendingCursorOffset = 0;
    if (transientFromTailTap) {
      _tailTapTransientTouchedByBlockId[blockId] = false;
    }
    _s.insertBlockAfter(
      pageId: pageId,
      afterBlockId: page.blocks.last.id,
      block: FolioBlock(id: blockId, type: 'paragraph', text: ''),
    );
  }

  bool _isBlockSelected(String blockId) => _selectedBlockIds.contains(blockId);

  bool get _isAdditiveSelectionPressed {
    return HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
  }

  void _selectOnlyBlock(String blockId) {
    setState(() {
      _selectedBlockIds
        ..clear()
        ..add(blockId);
      _selectionAnchorBlockId = blockId;
    });
  }

  void _toggleBlockSelection(String blockId) {
    setState(() {
      if (_selectedBlockIds.contains(blockId)) {
        _selectedBlockIds.remove(blockId);
        if (_selectionAnchorBlockId == blockId) {
          _selectionAnchorBlockId = _selectedBlockIds.isEmpty
              ? null
              : _selectedBlockIds.first;
        }
      } else {
        _selectedBlockIds.add(blockId);
        _selectionAnchorBlockId = blockId;
      }
    });
  }

  void _selectBlockRange(FolioPage page, String blockId) {
    final anchorId = _selectionAnchorBlockId;
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
      _selectedBlockIds
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
    if (HardwareKeyboard.instance.isShiftPressed) {
      _selectBlockRange(page, blockId);
    } else if (_isAdditiveSelectionPressed) {
      _toggleBlockSelection(blockId);
    } else if (!_isBlockSelected(blockId) || _selectedBlockIds.length > 1) {
      _selectOnlyBlock(blockId);
    }
    if (requestFocus) {
      focusNode?.requestFocus();
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
    _dragSelectionActive = true;
    _dragSelectionOriginBlockId = blockId;
    _dragSelectionBaseIds = _isAdditiveSelectionPressed
        ? (Set<String>.from(_selectedBlockIds)..remove(blockId))
        : <String>{};
    _handleBlockSelection(page, blockId, focusNode: focusNode);
  }

  void _updateDragSelection(FolioPage page, String blockId) {
    if (!_dragSelectionActive) return;
    final originBlockId = _dragSelectionOriginBlockId;
    if (originBlockId == null) return;
    final nextIds = _rangeBlockIds(page, originBlockId, blockId);
    final combinedIds = <String>{..._dragSelectionBaseIds, ...nextIds};
    if (setEquals(combinedIds, _selectedBlockIds)) return;
    setState(() {
      _selectedBlockIds
        ..clear()
        ..addAll(combinedIds);
      _selectionAnchorBlockId = originBlockId;
    });
  }

  void _endDragSelection() {
    _dragSelectionActive = false;
    _dragSelectionOriginBlockId = null;
    _dragSelectionBaseIds.clear();
  }

  List<String> _selectedIdsForAction(FolioPage page, String triggerBlockId) {
    if (_selectedBlockIds.contains(triggerBlockId) &&
        _selectedBlockIds.length > 1) {
      return page.blocks
          .where((block) => _selectedBlockIds.contains(block.id))
          .map((block) => block.id)
          .toList();
    }
    return [triggerBlockId];
  }

  void _deleteSelectedBlocks(FolioPage page, List<String> blockIds) {
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
    _pendingFocusBlockId = targetBlock.id;
    _pendingCursorOffset = targetBlock.text.length;
    for (final blockId in idsToDelete) {
      _s.removeBlockIfMultiple(page.id, blockId);
    }
    setState(() {
      _selectedBlockIds
        ..clear()
        ..add(targetBlock.id);
      _selectionAnchorBlockId = targetBlock.id;
    });
  }

  void _duplicateSelectedBlocks(FolioPage page, List<String> blockIds) {
    if (blockIds.isEmpty) return;
    final blocks = page.blocks.where((b) => blockIds.contains(b.id)).toList();
    if (blocks.isEmpty) return;
    final clones = _s.cloneBlocksWithNewIds(page.id, blocks);
    if (clones.isEmpty) return;
    var afterBlockId = blocks.last.id;
    for (final clone in clones) {
      _s.insertBlockAfter(
        pageId: page.id,
        afterBlockId: afterBlockId,
        block: clone,
      );
      afterBlockId = clone.id;
    }
    _pendingFocusBlockId = clones.first.id;
    _pendingCursorOffset = clones.first.text.length;
    setState(() {
      _selectedBlockIds
        ..clear()
        ..addAll(clones.map((b) => b.id));
      _selectionAnchorBlockId = clones.first.id;
    });
  }

  void _clearBlockSelection() {
    if (_selectedBlockIds.isEmpty) return;
    setState(() {
      _selectedBlockIds.clear();
      _selectionAnchorBlockId = null;
    });
  }

  void _handleTailBlankTap(TapDownDetails details, FolioPage page) {
    if (page.blocks.isEmpty) return;
    final lastId = page.blocks.last.id;
    final ctx = _blockScrollKeys[lastId]?.currentContext;
    if (ctx == null) return;
    final render = ctx.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final topLeft = render.localToGlobal(Offset.zero);
    final bottomY = topLeft.dy + render.size.height;
    final tapY = details.globalPosition.dy;
    // Solo crear bloque cuando el tap cae realmente por debajo del último bloque.
    if (tapY <= bottomY + 2) return;
    _addBlock(page.id, transientFromTailTap: true);
  }

  Color _blockRowFill(
    ColorScheme scheme,
    int index,
    FocusNode focus,
    bool selected,
  ) {
    final hovered = _hoveredBlockIndex == index;
    final focused = focus.hasFocus;
    if (selected) {
      return scheme.primaryContainer.withValues(alpha: focused ? 0.42 : 0.3);
    }
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

  void _duplicateBlock(FolioPage page, FolioBlock block, int index) {
    final clones = _s.cloneBlocksWithNewIds(page.id, [block]);
    if (clones.isEmpty) return;
    _pendingFocusIndex = index + 1;
    _pendingCursorOffset = clones.first.text.length;
    _s.insertBlockAfter(
      pageId: page.id,
      afterBlockId: block.id,
      block: clones.first,
    );
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
    final androidPhoneLayout = FolioAdaptive.isAndroidPhoneWidth(
      MediaQuery.sizeOf(context).width,
    );
    final readOnlyMode = widget.readOnlyMode;
    final selectedCount = _selectedBlockIds.length;
    final enterHint = widget.appSettings.enterCreatesNewBlock
        ? 'Enter: bloque nuevo (en código: Enter = línea)'
        : 'Enter: nueva línea';
    final mono = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFamily: 'monospace',
    );

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!readOnlyMode)
            Padding(
              padding: EdgeInsets.fromLTRB(
                androidPhoneLayout ? 14 : 12,
                0,
                androidPhoneLayout ? 14 : 12,
                androidPhoneLayout ? 8 : 10,
              ),
              child: Text(
                androidPhoneLayout
                    ? '$enterHint · / para bloques · toca el bloque para más acciones'
                    : '$enterHint · Shift+Enter: línea · / tipos · # título (misma línea) · - · * · [] · ``` espacio · tabla/imagen en / · formato: barra al enfocar o ** _ <u> ` ~~',
                textAlign: TextAlign.center,
                style: mono,
              ),
            ),
          if (!readOnlyMode && selectedCount > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.24),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: androidPhoneLayout ? double.infinity : null,
                      child: Text(
                        '$selectedCount bloques seleccionados · Shift: rango · Ctrl/Cmd: alternar',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _duplicateSelectedBlocks(
                        page,
                        _selectedBlockIds.toList(),
                      ),
                      icon: const Icon(Icons.copy_all_rounded, size: 18),
                      label: const Text('Duplicar'),
                    ),
                    TextButton.icon(
                      onPressed: page.blocks.length > 1
                          ? () => _deleteSelectedBlocks(
                              page,
                              _selectedBlockIds.toList(),
                            )
                          : null,
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text('Eliminar'),
                    ),
                    IconButton(
                      onPressed: _clearBlockSelection,
                      tooltip: 'Limpiar selección',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Listener(
              onPointerUp: (_) => _endDragSelection(),
              onPointerCancel: (_) => _endDragSelection(),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: readOnlyMode
                    ? null
                    : (details) => _handleTailBlankTap(details, page),
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
                    scrollController: _blockListScrollController,
                    padding: EdgeInsets.fromLTRB(
                      androidPhoneLayout ? (readOnlyMode ? 6 : 12) : 10,
                      0,
                      androidPhoneLayout ? (readOnlyMode ? 6 : 12) : 10,
                      androidPhoneLayout ? 112 : 24,
                    ),
                    buildDefaultDragHandles: false,
                    itemCount: page.blocks.length,
                    onReorder: (oldIndex, newIndex) =>
                        _onBlocksReordered(page, oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final b = page.blocks[index];
                      final ctrl = _controllers[index];
                      final focus = _focusNodes[index];
                      final style = _styleFor(b.type, theme.textTheme);
                      final selected = _isBlockSelected(b.id);
                      final showActions =
                          !readOnlyMode &&
                          (_hoveredBlockIndex == index ||
                              selected ||
                              focus.hasFocus ||
                              _menuOpenBlockId == b.id ||
                              (!androidPhoneLayout &&
                                  _selectedBlockIds.length > 1));
                      final showInlineEditControls =
                          !readOnlyMode &&
                          (showActions || selected || focus.hasFocus);
                      return KeyedSubtree(
                        key: ValueKey('block_row_${b.id}'),
                        child: MouseRegion(
                          onEnter: (_) {
                            if (_hoveredBlockIndex != index) {
                              setState(() => _hoveredBlockIndex = index);
                            }
                          },
                          onExit: (_) {
                            if (_hoveredBlockIndex == index) {
                              setState(() => _hoveredBlockIndex = null);
                            }
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: readOnlyMode
                                ? null
                                : (_) => _handleBlockSelection(
                                    page,
                                    b.id,
                                    focusNode: focus,
                                  ),
                            onPanStart: readOnlyMode
                                ? null
                                : (_) => _beginDragSelection(
                                    page,
                                    b.id,
                                    focusNode: focus,
                                  ),
                            onPanUpdate: readOnlyMode
                                ? null
                                : (_) => _updateDragSelection(page, b.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOut,
                              margin: EdgeInsets.only(
                                bottom: androidPhoneLayout ? 6 : 1,
                              ),
                              decoration: BoxDecoration(
                                color: _blockRowFill(
                                  scheme,
                                  index,
                                  focus,
                                  selected,
                                ),
                                borderRadius: BorderRadius.circular(
                                  androidPhoneLayout ? 14 : 6,
                                ),
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
                                showInlineEditControls: showInlineEditControls,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
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
    final androidPhoneLayout = FolioAdaptive.isAndroidPhoneWidth(
      MediaQuery.sizeOf(context).width,
    );
    PopupMenuItem<String> item(
      BuildContext ctx, {
      required String value,
      required IconData icon,
      required String label,
      Color? iconColor,
    }) {
      final scheme = Theme.of(ctx).colorScheme;
      return PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: Semantics(
        button: true,
        label: AppLocalizations.of(context).blockOptions,
        child: Icon(
          Icons.more_vert_rounded,
          size: androidPhoneLayout ? 20 : 22,
        ),
      ),
      tooltip: AppLocalizations.of(context).blockOptions,
      style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: androidPhoneLayout ? const EdgeInsets.all(4) : null,
        minimumSize: androidPhoneLayout ? const Size(28, 28) : null,
        tapTargetSize: androidPhoneLayout
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
      ),
      onOpened: () => setState(() => _menuOpenBlockId = b.id),
      onCanceled: () {
        if (_menuOpenBlockId == b.id) {
          setState(() => _menuOpenBlockId = null);
        }
      },
      onSelected: (v) {
        setState(() => _menuOpenBlockId = null);
        if (v == 'del' && page.blocks.length > 1) {
          _deleteSelectedBlocks(page, _selectedIdsForAction(page, b.id));
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
            final instruction = c.text.trim();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              c.dispose();
            });
            if (go != true || instruction.isEmpty) return;
            try {
              final preview = await _s.previewRewriteBlockWithAi(
                pageId: page.id,
                blockId: b.id,
                instruction: instruction,
              );
              if (!mounted) return;

              final theme = Theme.of(context);
              final scheme = theme.colorScheme;
              final baseStyle = theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                height: 1.35,
              );
              final accept = await showDialog<bool>(
                context: menuContext,
                builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Vista previa'),
                    content: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: SingleChildScrollView(
                        child: FolioAiTypewriterMessage(
                          fullText: preview.text,
                          style: baseStyle ??
                              TextStyle(color: scheme.onSurface, height: 1.35),
                          selectable: true,
                        ),
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
                  );
                },
              );
              if (accept != true || !mounted) return;

              await _applyTypewriterToBlock(
                pageId: page.id,
                blockId: b.id,
                fullText: preview.text,
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
        } else if (v == 'appearance') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_editBlockAppearance(page, b));
          });
        } else if (v == 'up' && index > 0) {
          _moveBlock(page.id, b.id, -1);
        } else if (v == 'down' && index < page.blocks.length - 1) {
          _moveBlock(page.id, b.id, 1);
        } else if (v == 'dup') {
          final selectedIds = _selectedIdsForAction(page, b.id);
          if (selectedIds.length > 1) {
            _duplicateSelectedBlocks(page, selectedIds);
          } else {
            _duplicateBlock(page, b, index);
          }
        } else if (v == 'open_external') {
          final target = b.type == 'image'
              ? b.text
              : (const {
                      'file',
                      'video',
                      'audio',
                      'bookmark',
                      'embed',
                    }.contains(b.type)
                    ? b.url
                    : null);
          unawaited(_openBlockUrlExternal(target));
        } else if (v == 'copy_link') {
          final target = b.type == 'image'
              ? b.text.trim()
              : (const {
                      'file',
                      'video',
                      'audio',
                      'bookmark',
                      'embed',
                    }.contains(b.type)
                    ? (b.url ?? '').trim()
                    : '');
          if (target.isNotEmpty) {
            unawaited(Clipboard.setData(ClipboardData(text: target)));
          }
        } else if (v == 'size_smaller') {
          _nudgeImageWidth(page, b, -0.1);
        } else if (v == 'size_larger') {
          _nudgeImageWidth(page, b, 0.1);
        } else if (v == 'size_50') {
          _s.setBlockImageWidth(page.id, b.id, 0.5);
        } else if (v == 'size_75') {
          _s.setBlockImageWidth(page.id, b.id, 0.75);
        } else if (v == 'size_100') {
          _s.setBlockImageWidth(page.id, b.id, 1.0);
        } else if (v == 'img_pick') {
          unawaited(_pickImageForBlock(page.id, b.id, index));
        } else if (v == 'img_clear') {
          unawaited(_clearImageBlock(page.id, b.id, index));
        } else if (v == 'child_create') {
          _s.createChildPageLinkedToBlock(pageId: page.id, blockId: b.id);
          setState(() {});
        } else if (v == 'child_link') {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final picked = await _pickPageForChildBlock(
              menuContext,
              excludeId: page.id,
            );
            if (picked == null || !mounted) return;
            _s.updateBlockText(page.id, b.id, picked);
            setState(() {});
          });
        } else if (v == 'child_open') {
          final cid = b.text.trim();
          if (cid.isNotEmpty) {
            _s.selectPage(cid);
          }
        } else if (v == 'file_pick') {
          unawaited(_pickFileForBlock(page.id, b.id));
        } else if (v == 'file_clear') {
          _clearBlockUrl(page.id, b.id);
        } else if (v == 'video_pick') {
          unawaited(_pickVideoForBlock(page.id, b.id));
        } else if (v == 'video_clear') {
          _clearBlockUrl(page.id, b.id);
        } else if (v == 'audio_pick') {
          unawaited(_pickAudioForBlock(page.id, b.id));
        } else if (v == 'audio_clear') {
          _clearBlockUrl(page.id, b.id);
        } else if (v == 'template_edit_label') {
          unawaited(_editTemplateButtonLabel(page.id, b));
        } else if (v == 'bookmark_set_url') {
          unawaited(_editBookmarkUrlDialog(page.id, b.id, index));
        } else if (v == 'bookmark_clear') {
          _clearBlockUrl(page.id, b.id);
          _s.updateBlockText(page.id, b.id, '');
          final j = _controllerBlockIds.indexOf(b.id);
          if (j >= 0 && j < _controllers.length) {
            _ignoreShortcuts = true;
            _controllers[j].clear();
            _ignoreShortcuts = false;
          }
          if (mounted) setState(() {});
        } else if (v == 'embed_set_url') {
          unawaited(_editEmbedUrlDialog(page.id, b.id, index));
        } else if (v == 'embed_clear') {
          _clearBlockUrl(page.id, b.id);
          _s.updateBlockText(page.id, b.id, '');
          final j = _controllerBlockIds.indexOf(b.id);
          if (j >= 0 && j < _controllers.length) {
            _ignoreShortcuts = true;
            _controllers[j].clear();
            _ignoreShortcuts = false;
          }
          if (mounted) setState(() {});
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
        } else if (v == 'mermaid_edit') {
          setState(() => _mermaidEditingSourceIds.add(b.id));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final p2 = _s.selectedPage;
            if (p2 == null) return;
            final j = p2.blocks.indexWhere((x) => x.id == b.id);
            if (j < 0 || j >= _focusNodes.length) return;
            _focusNodes[j].requestFocus();
          });
        } else if (v == 'mermaid_hide') {
          setState(() => _mermaidEditingSourceIds.remove(b.id));
        }
      },
      itemBuilder: (ctx) {
        final data = b.type == 'table' ? FolioTableData.tryParse(b.text) : null;
        final db = b.type == 'database'
            ? FolioDatabaseData.tryParse(b.text)
            : null;
        final rows = data?.rowCount ?? 0;
        final cols = data?.cols ?? 0;
        final linkTarget = b.type == 'image'
            ? b.text.trim()
            : (const {
                    'file',
                    'video',
                    'audio',
                    'bookmark',
                    'embed',
                  }.contains(b.type)
                  ? (b.url ?? '').trim()
                  : '');
        final hasExternalTarget = linkTarget.isNotEmpty;
        final mediaSizeTypes = {
          'image',
          'file',
          'video',
          'bookmark',
          'embed',
          'audio',
        };
        final isChildLinked =
            b.type == 'child_page' &&
            b.text.trim().isNotEmpty &&
            _s.pages.any((p) => p.id == b.text.trim());
        return [
          if (_s.aiEnabled)
            item(
              ctx,
              value: 'ai_rewrite',
              icon: Icons.auto_fix_high_rounded,
              label: 'Reescribir con IA…',
            ),
          if (index > 0)
            item(
              ctx,
              value: 'up',
              icon: Icons.keyboard_arrow_up_rounded,
              label: 'Mover arriba',
            ),
          if (index < page.blocks.length - 1)
            item(
              ctx,
              value: 'down',
              icon: Icons.keyboard_arrow_down_rounded,
              label: 'Mover abajo',
            ),
          item(
            ctx,
            value: 'dup',
            icon: Icons.copy_all_rounded,
            label: 'Duplicar bloque',
          ),
          if (_blockSupportsAppearance(b))
            item(
              ctx,
              value: 'appearance',
              icon: Icons.palette_outlined,
              label: 'Apariencia…',
            ),
          if (hasExternalTarget)
            item(
              ctx,
              value: 'open_external',
              icon: Icons.open_in_new_rounded,
              label: AppLocalizations.of(ctx).openExternal,
            ),
          if (hasExternalTarget)
            item(
              ctx,
              value: 'copy_link',
              icon: Icons.link_rounded,
              label: 'Copiar enlace',
            ),
          if (mediaSizeTypes.contains(b.type)) ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'size_smaller',
              icon: Icons.remove_rounded,
              label: AppLocalizations.of(ctx).blockSizeSmaller,
            ),
            item(
              ctx,
              value: 'size_larger',
              icon: Icons.add_rounded,
              label: AppLocalizations.of(ctx).blockSizeLarger,
            ),
            item(
              ctx,
              value: 'size_50',
              icon: Icons.photo_size_select_small_rounded,
              label: AppLocalizations.of(ctx).blockSizeHalf,
            ),
            item(
              ctx,
              value: 'size_75',
              icon: Icons.photo_size_select_large_rounded,
              label: AppLocalizations.of(ctx).blockSizeThreeQuarter,
            ),
            item(
              ctx,
              value: 'size_100',
              icon: Icons.fit_screen_rounded,
              label: AppLocalizations.of(ctx).blockSizeFull,
            ),
          ],
          if (b.type == 'child_page') ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'child_create',
              icon: Icons.note_add_rounded,
              label: 'Crear subpágina',
            ),
            item(
              ctx,
              value: 'child_link',
              icon: Icons.link_rounded,
              label: 'Enlazar página…',
            ),
            if (isChildLinked)
              item(
                ctx,
                value: 'child_open',
                icon: Icons.open_in_new_rounded,
                label: 'Abrir subpágina',
              ),
          ],
          if (b.type == 'image') ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'img_pick',
              icon: Icons.image_rounded,
              label: 'Elegir imagen…',
            ),
            if (b.text.isNotEmpty)
              item(
                ctx,
                value: 'img_clear',
                icon: Icons.delete_outline_rounded,
                label: 'Quitar imagen',
              ),
          ],
          if (b.type == 'code') ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'code_lang',
              icon: Icons.translate_rounded,
              label: 'Lenguaje del código…',
            ),
          ],
          if (b.type == 'mermaid') ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'mermaid_edit',
              icon: Icons.edit_note_rounded,
              label: 'Editar diagrama…',
            ),
            if (_mermaidEditingSourceIds.contains(b.id))
              item(
                ctx,
                value: 'mermaid_hide',
                icon: Icons.visibility_rounded,
                label: 'Volver a vista previa',
              ),
          ],
          if (b.type == 'file') ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'file_pick',
              icon: Icons.attach_file_rounded,
              label: 'Cambiar archivo…',
            ),
            if ((b.url ?? '').trim().isNotEmpty)
              item(
                ctx,
                value: 'file_clear',
                icon: Icons.delete_outline_rounded,
                label: 'Quitar archivo',
              ),
          ],
          if (b.type == 'video') ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'video_pick',
              icon: Icons.video_settings_rounded,
              label: 'Cambiar video…',
            ),
            if ((b.url ?? '').trim().isNotEmpty)
              item(
                ctx,
                value: 'video_clear',
                icon: Icons.delete_outline_rounded,
                label: 'Quitar video',
              ),
          ],
          if (b.type == 'audio') ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'audio_pick',
              icon: Icons.audio_file_rounded,
              label: 'Cambiar audio…',
            ),
            if ((b.url ?? '').trim().isNotEmpty)
              item(
                ctx,
                value: 'audio_clear',
                icon: Icons.delete_outline_rounded,
                label: 'Quitar audio',
              ),
          ],
          if (b.type == 'template_button') ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'template_edit_label',
              icon: Icons.title_rounded,
              label: 'Editar etiqueta…',
            ),
          ],
          if (b.type == 'bookmark') ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'bookmark_set_url',
              icon: Icons.link_rounded,
              label: AppLocalizations.of(ctx).bookmarkSetUrl,
            ),
            if ((b.url ?? '').trim().isNotEmpty)
              item(
                ctx,
                value: 'bookmark_clear',
                icon: Icons.delete_outline_rounded,
                label: AppLocalizations.of(ctx).bookmarkRemove,
              ),
          ],
          if (b.type == 'embed') ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'embed_set_url',
              icon: Icons.language_rounded,
              label: AppLocalizations.of(ctx).embedSetUrl,
            ),
            if ((b.url ?? '').trim().isNotEmpty)
              item(
                ctx,
                value: 'embed_clear',
                icon: Icons.delete_outline_rounded,
                label: AppLocalizations.of(ctx).embedRemove,
              ),
          ],
          if (b.type == 'table' && data != null) ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'table_row_add',
              icon: Icons.table_rows_rounded,
              label: 'Añadir fila',
            ),
            if (rows > 1)
              item(
                ctx,
                value: 'table_row_rem',
                icon: Icons.table_rows_outlined,
                label: 'Quitar última fila',
              ),
            item(
              ctx,
              value: 'table_col_add',
              icon: Icons.view_column_rounded,
              label: 'Añadir columna',
            ),
            if (cols > 1)
              item(
                ctx,
                value: 'table_col_rem',
                icon: Icons.view_column_outlined,
                label: 'Quitar última columna',
              ),
          ],
          if (b.type == 'database' && db != null) ...[
            const PopupMenuDivider(),
            item(
              ctx,
              value: 'db_row_add',
              icon: Icons.playlist_add_rounded,
              label: 'Añadir fila',
            ),
            item(
              ctx,
              value: 'db_col_add',
              icon: Icons.add_chart_rounded,
              label: 'Añadir propiedad',
            ),
          ],
          const PopupMenuDivider(),
          item(
            ctx,
            value: 'pick_type',
            icon: Icons.auto_awesome_motion_rounded,
            iconColor: Theme.of(ctx).colorScheme.primary,
            label: 'Cambiar tipo de bloque…',
          ),
          if (page.blocks.length > 1) const PopupMenuDivider(),
          if (page.blocks.length > 1)
            item(
              ctx,
              value: 'del',
              icon: Icons.delete_forever_rounded,
              iconColor: Theme.of(ctx).colorScheme.error,
              label: 'Eliminar bloque',
            ),
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
  static const _menuSlotWidthPhone = 28.0;
  static const _dragGutterWidth = 22.0;

  /// Ancho fijo para viñeta / checkbox / hueco: alinea el texto con Notion.
  static const _markerColumnWidth = 30.0;
  static const _markerColumnWidthPhone = 22.0;
  static const _markerEmptyColumnWidthPhone = 6.0;

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
    return SizedBox(
      width: compactReadOnlyMobile
          ? 0
          : (androidPhoneLayout ? _menuSlotWidthPhone : _menuSlotWidth),
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
    required bool showInlineEditControls,
  }) {
    final androidPhoneLayout = FolioAdaptive.isAndroidPhoneWidth(
      MediaQuery.sizeOf(context).width,
    );
    final compactReadOnlyMobile = widget.readOnlyMode && androidPhoneLayout;
    final menu = _blockMenuButton(
      menuContext: context,
      page: page,
      b: block,
      index: index,
    );
    final iconColor = scheme.onSurfaceVariant.withValues(alpha: 0.85);

    final dragHandle = !androidPhoneLayout && showActions
        ? Tooltip(
            message: AppLocalizations.of(context).dragToReorder,
            waitDuration: const Duration(milliseconds: 400),
            child: ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: AppLocalizations.of(context).dragToReorder,
                button: true,
                child: BlockEditorDragHandle(iconColor: iconColor),
              ),
            ),
          )
        : SizedBox(
            width: androidPhoneLayout ? 0 : _dragGutterWidth,
            height: 32,
          );

    Widget marker;
    switch (block.type) {
      case 'todo':
        marker = SizedBox(
          width: compactReadOnlyMobile
              ? 20
              : (androidPhoneLayout
                    ? _markerColumnWidthPhone
                    : _markerColumnWidth),
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
                  onChanged: widget.readOnlyMode
                      ? null
                      : (v) {
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
        final markerStyle = _applyBlockAppearanceToTextStyle(
          style,
          scheme,
          block,
        );
        marker = SizedBox(
          width: compactReadOnlyMobile
              ? 16
              : (androidPhoneLayout
                    ? _markerColumnWidthPhone
                    : _markerColumnWidth),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Text('•', style: markerStyle.copyWith(height: 1.0)),
            ),
          ),
        );
        break;
      case 'numbered':
        final n = _orderedListNumber(page.blocks, index);
        final markerStyle = _applyBlockAppearanceToTextStyle(
          style,
          scheme,
          block,
        );
        marker = SizedBox(
          width: compactReadOnlyMobile
              ? 20
              : (androidPhoneLayout
                    ? _markerColumnWidthPhone
                    : _markerColumnWidth),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, top: 2),
              child: Text('$n.', style: markerStyle.copyWith(height: 1.0)),
            ),
          ),
        );
        break;
      default:
        marker = SizedBox(
          width: compactReadOnlyMobile
              ? 0
              : (androidPhoneLayout
                    ? _markerEmptyColumnWidthPhone
                    : _markerColumnWidth),
        );
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
              child: IgnorePointer(
                ignoring: readOnlyMode,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: readOnlyMode
                      ? null
                      : () {
                          focus.requestFocus();
                        },
                  child: TableBlockEditor(
                    json: block.text,
                    scheme: scheme,
                    textTheme: theme.textTheme,
                    firstCellFocusNode: focus,
                    showToolbar: showInlineEditControls,
                    onChanged: (enc) =>
                        _onTableEncoded(page.id, block.id, index, enc),
                  ),
                ),
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
              child: IgnorePointer(
                ignoring: readOnlyMode,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: readOnlyMode ? null : () {},
                  child: DatabaseBlockEditor(
                    json: block.text,
                    scheme: scheme,
                    textTheme: theme.textTheme,
                    controlsVisible: showInlineEditControls,
                    onChanged: (enc) =>
                        _onTableEncoded(page.id, block.id, index, enc),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'equation') {
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
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'LaTeX',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
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
                          key: ObjectKey(focus),
                          controller: codeCtrl,
                          focusNode: focus,
                          readOnly: readOnlyMode,
                          minLines: 2,
                          maxLines: null,
                          wrap: true,
                          textStyle: _styleFor('code', theme.textTheme),
                          decoration: const BoxDecoration(),
                          padding: const EdgeInsets.all(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FolioEquationPreview(
                    latex: block.text,
                    textStyle: theme.textTheme.bodyLarge,
                    scheme: scheme,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'mermaid') {
      final codeCtrl = ctrl as CodeController;
      final showSourceEditor =
          block.text.trim().isEmpty ||
          _mermaidEditingSourceIds.contains(block.id);
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
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Mermaid',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  if (showSourceEditor) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CodeTheme(
                        data: folioCodeThemeData(theme),
                        child: ColoredBox(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.55,
                          ),
                          child: CodeField(
                            key: ObjectKey(focus),
                            controller: codeCtrl,
                            focusNode: focus,
                            readOnly: readOnlyMode,
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
                    const SizedBox(height: 10),
                    FolioMermaidPreview(source: block.text),
                  ] else
                    Focus(
                      focusNode: focus,
                      child: GestureDetector(
                        onTap: () => focus.requestFocus(),
                        behavior: HitTestBehavior.opaque,
                        child: FolioMermaidPreview(source: block.text),
                      ),
                    ),
                ],
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
                          readOnly: readOnlyMode,
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
      final wf = _imageWidthFor(block);
      final boxH = (260 * (0.4 + 0.6 * wf)).clamp(140.0, 420.0);
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final targetW = (maxW * wf).clamp(120.0, maxW);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: targetW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showActions)
                            _blockMediaWidthToolbar(page, block, theme),
                          SizedBox(
                            height: boxH,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: FutureBuilder<File?>(
                                future: _resolveBlockUrlFileCached(block.url),
                                builder: (context, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (snap.hasError) {
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          ).fileResolveError,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: scheme.error),
                                        ),
                                        const SizedBox(height: 8),
                                        FilledButton.tonalIcon(
                                          onPressed: () => _pickFileForBlock(
                                            page.id,
                                            block.id,
                                          ),
                                          icon: const Icon(
                                            Icons.attach_file_rounded,
                                          ),
                                          label: Text(
                                            AppLocalizations.of(
                                              context,
                                            ).replaceFile,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  final file = snap.data;
                                  if (file == null) {
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if ((block.url ?? '').trim().isNotEmpty)
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            ).fileMissing,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(color: scheme.error),
                                          ),
                                        const SizedBox(height: 8),
                                        FilledButton.tonalIcon(
                                          onPressed: () => _pickFileForBlock(
                                            page.id,
                                            block.id,
                                          ),
                                          icon: const Icon(
                                            Icons.attach_file_rounded,
                                          ),
                                          label: Text(
                                            (block.url ?? '').trim().isEmpty
                                                ? AppLocalizations.of(
                                                    context,
                                                  ).chooseFile
                                                : AppLocalizations.of(
                                                    context,
                                                  ).replaceFile,
                                          ),
                                        ),
                                        if ((block.url ?? '')
                                            .trim()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          TextButton(
                                            onPressed: () => _clearBlockUrl(
                                              page.id,
                                              block.id,
                                            ),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).removeFile,
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
                                    onOpenExternal: () =>
                                        _openBlockUrlExternal(block.url),
                                    onReplace: () =>
                                        _pickFileForBlock(page.id, block.id),
                                    onClear: () =>
                                        _clearBlockUrl(page.id, block.id),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'bookmark') {
      final url = (block.url ?? '').trim();
      final host = Uri.tryParse(url)?.host ?? '';
      final wf = _imageWidthFor(block);
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final targetW = (maxW * wf).clamp(120.0, maxW);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: targetW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showActions)
                            _blockMediaWidthToolbar(page, block, theme),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.35,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (host.isNotEmpty)
                                  Text(
                                    host,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                if (host.isNotEmpty) const SizedBox(height: 6),
                                TextField(
                                  controller: ctrl,
                                  focusNode: focus,
                                  readOnly: widget.readOnlyMode,
                                  showCursor: !widget.readOnlyMode,
                                  maxLines: null,
                                  minLines: 1,
                                  style: theme.textTheme.titleSmall,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: AppLocalizations.of(
                                      context,
                                    ).bookmarkTitleHint,
                                  ),
                                ),
                                if (url.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    ).bookmarkBlockHint,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    url,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () => unawaited(
                                          _openBlockUrlExternal(block.url),
                                        ),
                                        icon: const Icon(
                                          Icons.open_in_new_rounded,
                                          size: 18,
                                        ),
                                        label: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).bookmarkOpenLink,
                                        ),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => unawaited(
                                          _editBookmarkUrlDialog(
                                            page.id,
                                            block.id,
                                            index,
                                          ),
                                        ),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).bookmarkSetUrl,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'embed') {
      final url = (block.url ?? '').trim();
      final wf = _imageWidthFor(block);
      final embedH = (360 * (0.45 + 0.55 * wf)).clamp(200.0, 560.0);
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final targetW = (maxW * wf).clamp(120.0, maxW);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: targetW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showActions)
                            _blockMediaWidthToolbar(page, block, theme),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: embedH,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: url.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).embedEmptyHint,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    )
                                  : FolioEmbedWebView(url: url, scheme: scheme),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'audio') {
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
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
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
                    final file = snap.data;
                    if (file == null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Elige un archivo de audio',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () => unawaited(
                              _pickAudioForBlock(page.id, block.id),
                            ),
                            icon: const Icon(Icons.audio_file_rounded),
                            label: const Text('Elegir audio…'),
                          ),
                        ],
                      );
                    }
                    return FolioAudioBlockPlayer(file: file, scheme: scheme);
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'video') {
      final rawU = (block.url ?? '').trim();
      final wf = _imageWidthFor(block);
      final ytId = rawU.startsWith('http://') || rawU.startsWith('https://')
          ? folioYoutubeVideoIdFromUrl(rawU)
          : null;
      if (ytId != null) {
        final vidH = (220 * (0.45 + 0.55 * wf)).clamp(120.0, 320.0);
        return Padding(
          padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _blockMenuSlot(showActions: showActions, menu: menu),
              dragHandle,
              marker,
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final targetW = (maxW * wf).clamp(120.0, maxW);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: targetW,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showActions)
                              _blockMediaWidthToolbar(page, block, theme),
                            Container(
                              height: vidH,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: FolioYoutubePreviewCard(
                                        pageUrl: rawU,
                                        videoId: ytId,
                                        scheme: scheme,
                                        compact: true,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        _clearBlockUrl(page.id, block.id),
                                    child: Text(
                                      AppLocalizations.of(context).removeVideo,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
      final localH = (200 * (0.45 + 0.55 * wf)).clamp(120.0, 300.0);
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final targetW = (maxW * wf).clamp(120.0, maxW);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: targetW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showActions)
                            _blockMediaWidthToolbar(page, block, theme),
                          SizedBox(
                            height: localH,
                            child: Container(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: FutureBuilder<File?>(
                                future: _resolveBlockUrlFileCached(block.url),
                                builder: (context, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (snap.hasError) {
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          ).videoResolveError,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: scheme.error),
                                        ),
                                        const SizedBox(height: 8),
                                        FilledButton.tonal(
                                          onPressed: () => _pickVideoForBlock(
                                            page.id,
                                            block.id,
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            ).replaceVideo,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  final file = snap.data;
                                  if (file == null) {
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if ((block.url ?? '').trim().isNotEmpty)
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            ).videoMissing,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(color: scheme.error),
                                          ),
                                        const SizedBox(height: 8),
                                        FilledButton.tonal(
                                          onPressed: () => _pickVideoForBlock(
                                            page.id,
                                            block.id,
                                          ),
                                          child: Text(
                                            (block.url ?? '').trim().isEmpty
                                                ? AppLocalizations.of(
                                                    context,
                                                  ).chooseVideo
                                                : AppLocalizations.of(
                                                    context,
                                                  ).replaceVideo,
                                          ),
                                        ),
                                        if ((block.url ?? '')
                                            .trim()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          TextButton(
                                            onPressed: () => _clearBlockUrl(
                                              page.id,
                                              block.id,
                                            ),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).removeVideo,
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
                                    onOpenExternal: () =>
                                        _openBlockUrlExternal(block.url),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'toggle') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: FolioToggleBlockBody(
                pageId: page.id,
                block: block,
                session: _s,
                colorScheme: scheme,
                textTheme: theme.textTheme,
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'toc') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: FolioTocBlockBody(
                pageId: page.id,
                blocks: page.blocks,
                session: _s,
                scheme: scheme,
                textTheme: theme.textTheme,
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'breadcrumb') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: FolioBreadcrumbBlockBody(
                pageId: page.id,
                session: _s,
                scheme: scheme,
                textTheme: theme.textTheme,
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'child_page') {
      final cid = block.text.trim();
      FolioPage? child;
      try {
        child = _s.pages.firstWhere((p) => p.id == cid);
      } catch (_) {
        child = null;
      }
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bloque página',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (child != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(child.title),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () => _s.selectPage(child!.id),
                      )
                    else
                      Text(
                        'Sin subpágina enlazada.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (!widget.readOnlyMode) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilledButton.tonal(
                            onPressed: () {
                              _s.createChildPageLinkedToBlock(
                                pageId: page.id,
                                blockId: block.id,
                              );
                              setState(() {});
                            },
                            child: const Text('Crear subpágina'),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              final picked = await _pickPageForChildBlock(
                                context,
                                excludeId: page.id,
                              );
                              if (picked != null && mounted) {
                                _s.updateBlockText(page.id, block.id, picked);
                                setState(() {});
                              }
                            },
                            child: const Text('Enlazar página…'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'template_button') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: FolioTemplateButtonBlockBody(
                pageId: page.id,
                block: block,
                session: _s,
                scheme: scheme,
                textTheme: theme.textTheme,
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'task') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: FolioTaskBlockBody(
                pageId: page.id,
                block: block,
                session: _s,
                scheme: scheme,
                textTheme: theme.textTheme,
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == 'column_list') {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(block.depth * 28.0, 2, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _blockMenuSlot(showActions: showActions, menu: menu),
            dragHandle,
            marker,
            Expanded(
              child: FolioColumnListBlockBody(
                pageId: page.id,
                block: block,
                session: _s,
                scheme: scheme,
                textTheme: theme.textTheme,
                showActions: showActions,
              ),
            ),
          ],
        ),
      );
    }

    final isParagraph = block.type == 'paragraph';
    final isListLine =
        block.type == 'todo' ||
        block.type == 'bullet' ||
        block.type == 'numbered';

    const slashTypes = {
      'paragraph',
      'h1',
      'h2',
      'h3',
      'bullet',
      'numbered',
      'todo',
      'toggle',
      'quote',
      'callout',
    };
    final allowsSlash = slashTypes.contains(block.type);
    final String? slashTail = allowsSlash
        ? _slashFilterFromBlockText(ctrl.text)
        : null;
    final showSlashMenu = slashTail != null && _slashBlockId == block.id;
    final slashItems = showSlashMenu
        ? _catalogFilteredForSlash(slashTail)
        : const <BlockTypeDef>[];
    final mentionTail = allowsSlash
        ? _mentionFilterFromSelection(ctrl.text, ctrl.selection)
        : null;
    final showMentionMenu =
        !showSlashMenu && mentionTail != null && _mentionBlockId == block.id;
    final mentionItems = showMentionMenu
        ? _catalogFilteredForMention(mentionTail)
        : const <FolioPage>[];
    final slashPanelMaxH = math.min(
      192.0,
      math.max(100.0, MediaQuery.sizeOf(context).height * 0.25),
    );

    /// Vista previa mientras escribes: el [TextField] va **encima** (texto transparente)
    /// para no bloquear toques ni el cursor; el markdown queda detrás.
    /// Sin previa si solo hay `#`…`######` y espacios (el render no muestra nada útil).
    final showInlinePreview =
        allowsSlash &&
        !widget.readOnlyMode &&
        !focus.hasFocus &&
        ctrl.text.trim().isNotEmpty &&
        !_isIncompleteAtxHeadingLine(ctrl.text);

    var currentStyle = style;
    if (block.type == 'quote') {
      currentStyle = currentStyle.copyWith(
        fontStyle: FontStyle.italic,
        fontSize: currentStyle.fontSize! * 1.05,
        color: scheme.onSurface.withValues(alpha: 0.8),
      );
    }
    currentStyle = _applyBlockAppearanceToTextStyle(
      currentStyle,
      scheme,
      block,
    );
    final appearance = _blockAppearanceFor(block);
    final customBackground = _blockBackgroundColorFor(
      scheme,
      appearance.backgroundRole,
    );
    final customBackgroundBorder = _blockBackgroundBorderColorFor(
      scheme,
      appearance.backgroundRole,
    );

    final mdSheet = folioMarkdownStyleSheet(context, currentStyle, scheme);

    final field = TextField(
      controller: ctrl,
      focusNode: focus,
      readOnly: widget.readOnlyMode,
      showCursor: !widget.readOnlyMode,
      maxLines: null,
      minLines: 1,
      cursorColor: showInlinePreview ? scheme.onSurface : null,
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

    final stackedField = showInlinePreview
        ? Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Align(
                  alignment: isParagraph
                      ? AlignmentDirectional.topStart
                      : AlignmentDirectional.centerStart,
                  child: FolioMarkdownPreview(
                    data: ctrl.text,
                    styleSheet: mdSheet,
                    onFolioPageLink: _s.selectPage,
                  ),
                ),
              ),
              field,
            ],
          )
        : field;

    final readOnlyMarkdown = FolioMarkdownPreview(
      data: ctrl.text,
      styleSheet: mdSheet,
      onFolioPageLink: _s.selectPage,
    );

    final blockContent = widget.readOnlyMode && allowsSlash
        ? readOnlyMarkdown
        : stackedField;

    Widget textContainer = blockContent;
    if (block.type == 'quote') {
      textContainer = Container(
        padding: EdgeInsets.fromLTRB(
          12,
          customBackground != null ? 8 : 2,
          customBackground != null ? 12 : 0,
          customBackground != null ? 8 : 2,
        ),
        decoration: BoxDecoration(
          color: customBackground,
          borderRadius: customBackground != null
              ? BorderRadius.circular(12)
              : null,
          border: Border(
            left: BorderSide(color: scheme.outlineVariant, width: 4),
          ),
        ),
        child: blockContent,
      );
    } else if (block.type == 'callout') {
      final calloutTone = _calloutToneForIcon(block.icon);
      textContainer = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              customBackground ??
              _calloutBackgroundForTone(scheme, calloutTone),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: customBackground != null
                ? customBackgroundBorder
                : _calloutBorderForTone(scheme, calloutTone),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _calloutChipForTone(scheme, calloutTone),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: MouseRegion(
                        cursor: widget.readOnlyMode
                            ? MouseCursor.defer
                            : SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.readOnlyMode
                              ? null
                              : () async {
                                  final emoji = await _pickEmoji(context);
                                  if (emoji != null) {
                                    _s.updateBlockIcon(
                                      page.id,
                                      block.id,
                                      emoji,
                                    );
                                  }
                                },
                          child: FolioIconTokenView(
                            appSettings: widget.appSettings,
                            token: block.icon,
                            fallbackText: '💡',
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Tipo de callout',
                    enabled: !widget.readOnlyMode,
                    onSelected: widget.readOnlyMode
                        ? null
                        : (emoji) =>
                              _s.updateBlockIcon(page.id, block.id, emoji),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: '💡', child: Text('💡 Info')),
                      PopupMenuItem(value: '✅', child: Text('✅ Éxito')),
                      PopupMenuItem(value: '⚠️', child: Text('⚠️ Warning')),
                      PopupMenuItem(value: '🚨', child: Text('🚨 Error')),
                      PopupMenuItem(value: 'ℹ️', child: Text('ℹ️ Nota')),
                    ],
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: scheme.onSurfaceVariant,
                    ),
                    constraints: const BoxConstraints(minWidth: 34),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            Expanded(child: blockContent),
          ],
        ),
      );
    } else if (customBackground != null) {
      textContainer = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: customBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: customBackgroundBorder),
        ),
        child: blockContent,
      );
    }

    final showFloatingToolbar =
        !widget.readOnlyMode &&
        allowsSlash &&
        !showSlashMenu &&
        !showMentionMenu &&
        focus.hasFocus;

    if (showFloatingToolbar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showOrUpdateFormatToolbarOverlay(
          blockId: block.id,
          controller: ctrl,
          focusNode: focus,
          scheme: scheme,
          page: page,
          block: block,
        );
      });
    } else if (_formatToolbarOverlayBlockId == block.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _removeFormatToolbarOverlay();
      });
    }

    final editorSlot = showFloatingToolbar
        ? CompositedTransformTarget(
            link: _formatToolbarLayerLink,
            child: textContainer,
          )
        : textContainer;

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
                        child: BlockEditorInlineSlashList(
                          scrollController: _slashListScrollController,
                          theme: theme,
                          scheme: scheme,
                          items: slashItems,
                          selectedIndex: slashItems.isEmpty
                              ? 0
                              : _slashSelectedIndex.clamp(
                                  0,
                                  slashItems.length - 1,
                                ),
                          showSections: tail.trim().isEmpty,
                          onPick: _applyInlineSlashChoice,
                        ),
                      ),
              ),
            ),
          ),
        ],
      );
    } else if (showMentionMenu) {
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
                  minHeight: mentionItems.isEmpty ? 48 : 72,
                ),
                child: mentionItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Sin paginas',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _mentionListScrollController,
                        interactive: false,
                        thumbVisibility: true,
                        thickness: 3,
                        radius: const Radius.circular(3),
                        child: BlockEditorInlineMentionList(
                          scrollController: _mentionListScrollController,
                          theme: theme,
                          scheme: scheme,
                          items: mentionItems,
                          selectedIndex: mentionItems.isEmpty
                              ? 0
                              : _mentionSelectedIndex.clamp(
                                  0,
                                  mentionItems.length - 1,
                                ),
                          onPick: _applyInlineMentionChoice,
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
      padding: EdgeInsetsDirectional.fromSTEB(
        block.depth * (compactReadOnlyMobile ? 16.0 : 28.0),
        2,
        compactReadOnlyMobile ? 0 : 4,
        2,
      ),
      child: row,
    );
  }
}
