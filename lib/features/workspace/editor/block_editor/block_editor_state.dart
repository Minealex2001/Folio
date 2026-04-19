part of 'package:folio/features/workspace/editor/block_editor.dart';

@visibleForTesting
String? folioParseMarkdownCodeFenceShortcut(String text) {
  // Atajo de línea completa: ```lang (opcional) con espacios opcionales.
  // No usa trimLeft para evitar conversiones inesperadas en texto indentado.
  final m = RegExp(r'^```\s*([A-Za-z0-9_+\-]*)\s*$').firstMatch(text);
  if (m == null) return null;
  final raw = (m.group(1) ?? '').trim().toLowerCase();
  if (raw.isEmpty) return '';
  return switch (raw) {
    'js' => 'javascript',
    'ts' => 'typescript',
    'sh' => 'bash',
    'shell' => 'bash',
    'yml' => 'yaml',
    'text' => 'plaintext',
    _ => raw,
  };
}

class BlockEditorState extends State<BlockEditor> with _BlockRowBuild {
  static const _uuid = Uuid();
  final List<TextEditingController> _controllers = [];
  final Map<String, quill.QuillController> _quillByBlockId = {};
  final Map<String, Timer> _quillDebounceByBlockId = {};
  final Map<String, String> _quillLastMdByBlockId = {};
  final List<FocusNode> _focusNodes = [];
  final List<VoidCallback> _textListeners = [];
  final List<VoidCallback> _focusDecorListeners = [];
  String? _boundPageId;
  var _ignoreShortcuts = false;
  T _runWithShortcutsIgnored<T>(T Function() action) {
    final wasIgnoring = _ignoreShortcuts;
    _ignoreShortcuts = true;
    try {
      return action();
    } finally {
      _ignoreShortcuts = wasIgnoring;
    }
  }

  void _trimSlashRecents({int maxEntries = 32}) {
    if (_slashRecentByType.length <= maxEntries) return;
    final entries = _slashRecentByType.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final toRemove = _slashRecentByType.length - maxEntries;
    for (var i = 0; i < toRemove; i++) {
      _slashRecentByType.remove(entries[i].key);
    }
  }

  int? _pendingFocusIndex;
  int? _pendingCursorOffset;
  String? _pendingFocusBlockId;
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
  final Map<String, _CollabUploadProgress> _collabUploadByBlockId = {};
  final Map<String, int> _collabUploadTokenByBlockId = {};
  final Map<String, SecretKey> _collabRoomKeyCache = {};
  final Map<String, Future<SecretKey?>> _collabRoomKeyInFlight = {};
  final Map<String, String> _collabMediaCachePathByMediaId = {};
  final Map<String, int> _collabUploadLastUiMsByBlockId = {};
  final Map<String, double> _collabUploadLastProgressByBlockId = {};
  final Map<String, int> _collabUploadLastEtaSecByBlockId = {};

  /// Anclas para [VaultSession.requestScrollToBlock] (TOC).
  final Map<String, GlobalKey> _blockScrollKeys = {};

  final ScrollController _blockListScrollController = ScrollController();
  String? _prevPageIdForBlockScroll;
  int? _prevBlockCountForScroll;
  final Map<String, bool> _tailTapTransientTouchedByBlockId = {};
  String? _pendingTailTransientBlockId;
  bool _ensuringTrailingSentinel = false;
  String? _toolbarInteractionBlockId;
  int _toolbarInteractionToken = 0;

  /// Bloque cuyo [TextEditingController] tiene una selección no-colapsada
  /// (texto seleccionado). Se actualiza desde el textListener de cada bloque.
  String? _selectionActiveBlockId;

  void _onToolbarPointerDown(String blockId) {
    _toolbarInteractionToken++;
    _toolbarInteractionBlockId = blockId;
    if (!mounted) return;
    setState(() {});
  }

  void _onToolbarPointerUpOrCancel(String blockId) {
    if (_toolbarInteractionBlockId != blockId) return;
    final token = _toolbarInteractionToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Si hubo otra interacción más reciente, no limpiar aún.
      if (token != _toolbarInteractionToken) return;
      if (_toolbarInteractionBlockId != blockId) return;
      _toolbarInteractionBlockId = null;
      setState(() {});
    });
  }

  quill.QuillController _ensureQuillController({
    required String pageId,
    required FolioBlock block,
  }) {
    final existing = _quillByBlockId[block.id];
    if (existing != null) return existing;
    quill.Document doc;
    final deltaJson = block.richTextDeltaJson?.trim();
    if (deltaJson != null && deltaJson.isNotEmpty) {
      try {
        final raw = jsonDecode(deltaJson);
        final delta = Delta.fromJson(raw as List);
        doc = quill.Document.fromDelta(delta);
      } catch (_) {
        doc = FolioMarkdownQuillCodec.markdownToDocument(block.text);
      }
    } else {
      doc = FolioMarkdownQuillCodec.markdownToDocument(block.text);
    }
    _quillLastMdByBlockId[block.id] = block.text;
    final qc = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    void flushNow() {
      if (!mounted) return;
      final md = FolioMarkdownQuillCodec.documentToMarkdown(qc.document);
      final deltaStr = jsonEncode(qc.document.toDelta().toJson());
      final caret = qc.selection.baseOffset;
      _quillLastMdByBlockId[block.id] = md;
      _runWithShortcutsIgnored(() {
        _s.updateBlockText(pageId, block.id, md);
        // Persistencia dual: guardar Delta/JSON en el bloque.
        final page = _s.selectedPage;
        if (page != null && page.id == pageId) {
          final b = page.blocks.firstWhereOrNull((x) => x.id == block.id);
          if (b != null) {
            b.richTextDeltaJson = deltaStr;
          }
        }
        final idx = _controllerBlockIds.indexOf(block.id);
        if (idx >= 0 && idx < _controllers.length) {
          final safe = caret.clamp(0, md.length);
          _controllers[idx].value = TextEditingValue(
            text: md,
            selection: TextSelection.collapsed(offset: safe),
          );
        }
      });
    }

    void listener() {
      if (!mounted) return;
      final idx = _controllerBlockIds.indexOf(block.id);
      if (idx >= 0) {
        final plain = qc.document.toPlainText();
        _syncInlineOverlaysOnly(pageId, block.id, plain, qc.selection, idx);
      }

      // Rastrear selección activa para el toolbar flotante.
      final qSel = qc.selection;
      final hasQuillSelection = qSel.isValid && !qSel.isCollapsed;
      final wasActive = _selectionActiveBlockId == block.id;
      if (hasQuillSelection && !wasActive) {
        _selectionActiveBlockId = block.id;
        setState(() {});
      } else if (!hasQuillSelection && wasActive) {
        _selectionActiveBlockId = null;
        setState(() {});
      }

      // Convertir a markdown con debounce para evitar trabajo por tecla.
      _quillDebounceByBlockId[block.id]?.cancel();
      _quillDebounceByBlockId[block.id] = Timer(
        const Duration(milliseconds: 200),
        () {
          flushNow();
        },
      );
    }

    qc.addListener(listener);
    _quillByBlockId[block.id] = qc;
    return qc;
  }

  void _disposeQuillFor(String blockId) {
    _quillDebounceByBlockId.remove(blockId)?.cancel();
    final qc = _quillByBlockId.remove(blockId);
    qc?.dispose();
    _quillLastMdByBlockId.remove(blockId);
  }

  bool _isTrailingSentinel(FolioBlock b) {
    return b.type == 'paragraph' && b.depth == 0 && b.text.trim().isEmpty;
  }

  /// Garantiza que la página tenga un último bloque vacío (sentinela).
  /// Devuelve `true` si no hubo cambios; `false` si insertamos y debemos esperar
  /// a la siguiente notificación del session para continuar.
  bool _ensureTrailingSentinel(FolioPage page) {
    if (_ensuringTrailingSentinel) return true;
    if (page.blocks.isEmpty) return true;
    final last = page.blocks.last;
    if (_isTrailingSentinel(last)) return true;

    _ensuringTrailingSentinel = true;
    String? focusId;
    int? focusOff;
    for (
      var i = 0;
      i < _focusNodes.length && i < _controllerBlockIds.length;
      i++
    ) {
      if (_focusNodes[i].hasFocus) {
        focusId = _controllerBlockIds[i];
        focusOff = _controllers[i].selection.baseOffset.clamp(
          0,
          _controllers[i].text.length,
        );
        break;
      }
    }
    if (focusId != null) {
      _pendingFocusBlockId = focusId;
      _pendingCursorOffset = focusOff ?? 0;
    }
    final blockId = '${page.id}_${_uuid.v4()}';
    _s.insertBlockAfter(
      pageId: page.id,
      afterBlockId: last.id,
      block: FolioBlock(id: blockId, type: 'paragraph', text: ''),
    );
    _ensuringTrailingSentinel = false;
    return false;
  }

  VaultSession get _s => widget.session;
  bool get readOnlyMode => widget.readOnlyMode;

  /// Para partes del editor que no son métodos de [State] pero deben refrescar la UI.
  void _blockRowSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

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

  // ignore: unused_element
  bool _hasExpandedSelectionForBlockId(String blockId) {
    final idx = _controllerBlockIds.indexWhere((x) => x == blockId);
    if (idx < 0 || idx >= _controllers.length) return false;
    final sel = _controllers[idx].selection;
    return sel.isValid && !sel.isCollapsed;
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
          _runWithShortcutsIgnored(() {
            c.value = const TextEditingValue(
              text: '',
              selection: TextSelection.collapsed(offset: 0),
            );
            _s.updateBlockText(pid, id, '');
          });
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
    _trimSlashRecents();

    if (typeKey.startsWith('cmd_')) {
      if (idx >= 0 && idx < _controllers.length) {
        final c = _controllers[idx];
        _runWithShortcutsIgnored(() {
          c.value = const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          );
          _s.updateBlockText(pid, id, '');
        });
      }
      unawaited(_runInlineSlashAction(typeKey, pageId: pid, blockId: id));
      return;
    }

    _pendingFocusBlockId = id;
    _pendingCursorOffset = 0;
    _runWithShortcutsIgnored(() {
      // Remove the trailing slash command from the block's text.
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
    });
    if (mounted) setState(() {});
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
        _runWithShortcutsIgnored(() {
          _controllers[ci].value = TextEditingValue(
            text: date,
            selection: TextSelection.collapsed(offset: date.length),
          );
        });
      }
      return;
    }

    if (actionKey == 'cmd_mention_page') {
      final picked = await _pickPageForChildBlock(context, excludeId: pageId);
      if (picked == null || !mounted) return;
      final pIndex = _s.pages.indexWhere((p) => p.id == picked);
      if (pIndex < 0) return;
      final title = _s.pages[pIndex].title.trim();
      final l10n = AppLocalizations.of(context);
      final label = title.isEmpty ? '@${l10n.untitledFallback}' : '@$title';
      final markdown = '[$label](${folioPageLinkUri(picked)})';
      _s.updateBlockText(pageId, blockId, markdown);
      final ci = _controllerBlockIds.indexWhere((x) => x == blockId);
      if (ci >= 0 && ci < _controllers.length) {
        _runWithShortcutsIgnored(() {
          _controllers[ci].value = TextEditingValue(
            text: markdown,
            selection: TextSelection.collapsed(offset: markdown.length),
          );
        });
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
      var preservedOff = 0;
      final qc = _quillByBlockId[blockId];
      final idx = _controllerBlockIds.indexWhere((x) => x == blockId);
      if (qc != null && qc.selection.isValid) {
        preservedOff = qc.selection.baseOffset.clamp(
          0,
          qc.document.toPlainText().length,
        );
      } else if (idx >= 0 && idx < _controllers.length) {
        final c = _controllers[idx];
        if (c.selection.isValid) {
          preservedOff = c.selection.baseOffset.clamp(0, c.text.length);
        }
      }
      final choice = await _openBlockTypePicker(context);
      if (!mounted || choice == null || choice.startsWith('cmd_')) return;
      _pendingFocusBlockId = blockId;
      _pendingCursorOffset = preservedOff;
      _s.changeBlockType(pageId, blockId, choice);
      final p2 = _s.selectedPage;
      if (p2 != null && mounted) {
        final j = p2.blocks.indexWhere((x) => x.id == blockId);
        if (j >= 0 && j < _controllers.length) {
          final nb = p2.blocks[j];
          final len = nb.text.length;
          final off = preservedOff.clamp(0, len);
          _ignoreShortcuts = true;
          _controllers[j].value = TextEditingValue(
            text: nb.text,
            selection: TextSelection.collapsed(offset: off),
          );
          _ignoreShortcuts = false;
        }
      }
      if (mounted) setState(() {});
      return;
    }
  }

  void _dismissInlineMention() {
    _mentionBlockId = null;
    _mentionPageId = null;
    _mentionSelectedIndex = 0;
    if (mounted) setState(() {});
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
    final l10n = AppLocalizations.of(context);
    final label = title.isEmpty ? '@${l10n.untitledFallback}' : '@$title';
    final markdown = '[$label](${folioPageLinkUri(mentionedPageId)}) ';
    final next = c.text.replaceRange(start, caret, markdown);
    final offset = start + markdown.length;

    _runWithShortcutsIgnored(() {
      c.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: offset),
      );
      _s.updateBlockText(pid, bid, next);
    });
    _dismissInlineMention();
  }

  List<BlockTypeDef> _catalogFilteredForSlash(String q) {
    final l10n = AppLocalizations.of(context);
    final inline = _inlineSlashActionCatalog(l10n);
    final filtered = List<BlockTypeDef>.from(_catalogFiltered(q, l10n));
    final normalized = q.trim().toLowerCase();
    filtered.addAll(
      inline.where((a) {
        if (normalized.isEmpty) return true;
        return a.key.contains(normalized) ||
            a.label.toLowerCase().contains(normalized) ||
            a.hint.toLowerCase().contains(normalized);
      }),
    );
    if (filtered.length < 2) return filtered;
    final catalogIndex = {
      for (var i = 0; i < blockTypeTemplates.length; i++)
        blockTypeTemplates[i].key: i,
      for (var i = 0; i < inline.length; i++)
        inline[i].key: blockTypeTemplates.length + i,
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

    final sel = index < _controllers.length
        ? _controllers[index].selection
        : const TextSelection.collapsed(offset: -1);
    _syncInlineOverlaysOnly(pageId, blockId, text, sel, index);
  }

  /// Menús `/` y `@` sin persistir texto (p. ej. Quill en vivo antes del debounce).
  void _syncInlineOverlaysOnly(
    String pageId,
    String blockId,
    String text,
    TextSelection sel,
    int index,
  ) {
    if (_ignoreShortcuts) return;
    final pg = _s.selectedPage;
    if (pg == null || pg.id != pageId) return;
    final bi = pg.blocks.indexWhere((b) => b.id == blockId);
    if (bi < 0) return;
    final btype = pg.blocks[bi].type;
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

    final slashFilter =
        (sel.isValid
            ? _slashFilterFromPlainTextAndSelection(text, sel)
            : null) ??
        _slashFilterFromBlockText(text);
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

    final mentionFilter = sel.isValid
        ? _mentionFilterFromSelection(text, sel)
        : null;
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

  static String _quillMarkdownNormalize(String s) {
    return s.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trimRight();
  }

  /// `#` / `##` solos (o solo con espacios): el markdown no pinta texto y el
  /// campo con color transparente parece “vacío”; no usar vista previa aún.
  static bool _isIncompleteAtxHeadingLine(String text) {
    if (text.contains('\n') || text.contains('\r')) return false;
    return RegExp(r'^#{1,6}\s*$').hasMatch(text.trim());
  }

  /// Al pasar de WYSIWYG a otro tipo, el Quill del id queda huérfano: hay que
  /// liberarlo para que al volver se cree desde el markdown del modelo.
  void _disposeQuillForBlocksNoLongerStylable(FolioPage page) {
    for (final id in _quillByBlockId.keys.toList()) {
      FolioBlock? b;
      for (final x in page.blocks) {
        if (x.id == id) {
          b = x;
          break;
        }
      }
      if (b == null || !_stylableBlockTypes.contains(b.type)) {
        _disposeQuillFor(id);
      }
    }
  }

  /// Si el session actualizó `block.text` sin pasar por Quill (p. ej.
  /// [VaultSession.changeBlockType]), el documento Quill puede quedar obsoleto.
  void _reconcileStylableQuillDocumentsWithModel(FolioPage page) {
    for (final b in page.blocks) {
      if (!_stylableBlockTypes.contains(b.type)) continue;
      final qc = _quillByBlockId[b.id];
      if (qc == null) continue;
      final last = _quillLastMdByBlockId[b.id];
      if (last == b.text) continue;
      if (last != null &&
          _quillMarkdownNormalize(last) == _quillMarkdownNormalize(b.text)) {
        _quillLastMdByBlockId[b.id] = b.text;
        continue;
      }
      final oldPlain = qc.document.toPlainText();
      final oldSel = qc.selection;
      qc.document = FolioMarkdownQuillCodec.markdownToDocument(b.text);
      _quillLastMdByBlockId[b.id] = b.text;
      _quillDebounceByBlockId[b.id]?.cancel();
      final newPlain = qc.document.toPlainText();
      if (newPlain == oldPlain && oldSel.isValid) {
        qc.updateSelection(oldSel, quill.ChangeSource.remote);
      } else if (oldSel.isValid) {
        final o = oldSel.baseOffset.clamp(0, oldPlain.length);
        final at = o.clamp(0, newPlain.length);
        qc.updateSelection(
          TextSelection.collapsed(offset: at),
          quill.ChangeSource.remote,
        );
      }
    }
  }

  void _finalizePendingEditorFocus(FolioPage page) {
    int? idx = _pendingFocusIndex;
    final off = _pendingCursorOffset;
    final id = _pendingFocusBlockId;
    _pendingFocusIndex = null;
    _pendingCursorOffset = null;
    _pendingFocusBlockId = null;

    if (id != null) {
      final j = page.blocks.indexWhere((b) => b.id == id);
      if (j >= 0) idx = j;
    }
    if (idx == null || idx < 0 || idx >= _focusNodes.length) return;

    final iFocus = idx;
    final pageId = page.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = _s.selectedPage;
      if (p == null || p.id != pageId) return;
      if (iFocus >= _focusNodes.length || iFocus >= p.blocks.length) return;
      final block = p.blocks[iFocus];
      final bid = block.id;
      if (_controllerBlockIds.length != p.blocks.length ||
          iFocus >= _controllerBlockIds.length ||
          _controllerBlockIds[iFocus] != bid) {
        return;
      }
      _focusNodes[iFocus].requestFocus();
      if (_stylableBlockTypes.contains(block.type)) {
        final qc = _quillByBlockId[bid];
        if (qc != null) {
          final plainLen = qc.document.toPlainText().length;
          final o = (off ?? plainLen).clamp(0, plainLen);
          qc.updateSelection(
            TextSelection.collapsed(offset: o),
            quill.ChangeSource.remote,
          );
        }
      } else if (iFocus < _controllers.length) {
        final len = _controllers[iFocus].text.length;
        final o = (off ?? len).clamp(0, len);
        _controllers[iFocus].selection = TextSelection.collapsed(offset: o);
      }
    });
  }

  bool _tryMarkdownShortcut(
    String pageId,
    String blockId,
    String text,
    int index,
  ) {
    String? type;
    var replacement = '';
    final fenceLang = folioParseMarkdownCodeFenceShortcut(text);

    // No convertir con `# ` / `## ` / `### ` + espacio: pierde el foco y
    // impide escribir “# Título” en la misma línea. Usa /h1 o pega “# Texto”.
    if (text == '- ' || text == '* ') {
      type = 'bullet';
    } else if (text == '[] ' || text == '[ ] ') {
      type = 'todo';
    } else if (fenceLang != null) {
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

    _pendingFocusBlockId = blockId;
    _pendingCursorOffset = replacement.length;
    _ignoreShortcuts = true;
    _s.changeBlockType(pageId, blockId, type);
    if (type == 'code' && fenceLang != null && fenceLang.isNotEmpty) {
      _s.setBlockCodeLanguage(pageId, blockId, fenceLang);
      _pendingCursorOffset = 0;
    }
    _s.updateBlockText(pageId, blockId, replacement);
    if (index < _controllers.length) {
      _controllers[index].value = TextEditingValue(
        text: replacement,
        selection: TextSelection.collapsed(offset: replacement.length),
      );
    }
    _ignoreShortcuts = false;

    return true;
  }

  Future<String?> _openBlockTypePicker(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final androidPhoneLayout = FolioAdaptive.isAndroidPhoneWidth(w);
    final isHandheldPlatform =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final scheme = Theme.of(context).colorScheme;
    final barrier = scheme.scrim.withValues(alpha: FolioAlpha.scrim);

    // En escritorio/tablet, un sheet a pantalla completa se ve raro para un
    // selector rápido. Usamos un diálogo centrado con tamaño acotado.
    if (!isHandheldPlatform || !androidPhoneLayout) {
      return showDialog<String>(
        context: context,
        barrierColor: barrier,
        builder: (ctx) => const BlockTypePickerDialog(),
      );
    }

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: barrier,
      builder: (ctx) => const BlockTypePickerSheet(),
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

  String _blockTextColorLabel(AppLocalizations l10n, String? role) {
    switch (role) {
      case 'subtle':
        return l10n.blockEditorTextColorSubtle;
      case 'primary':
        return l10n.blockEditorTextColorPrimary;
      case 'secondary':
        return l10n.blockEditorTextColorSecondary;
      case 'tertiary':
        return l10n.blockEditorTextColorTertiary;
      case 'error':
        return l10n.blockEditorTextColorError;
      default:
        return l10n.blockEditorTextColorDefault;
    }
  }

  String _blockBackgroundLabel(AppLocalizations l10n, String? role) {
    switch (role) {
      case 'surface':
        return l10n.blockEditorBackgroundSurface;
      case 'primary':
        return l10n.blockEditorBackgroundPrimary;
      case 'secondary':
        return l10n.blockEditorBackgroundSecondary;
      case 'tertiary':
        return l10n.blockEditorBackgroundTertiary;
      case 'error':
        return l10n.blockEditorBackgroundError;
      default:
        return l10n.blockEditorBackgroundNone;
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
            final l10n = AppLocalizations.of(ctx);
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
                            l10n.blockEditorAppearanceTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.blockEditorAppearanceSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.blockEditorAppearanceSize,
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
                      l10n.blockEditorAppearanceTextColor,
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
                            label: _blockTextColorLabel(l10n, role),
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
                      l10n.blockEditorAppearanceBackground,
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
                            label: _blockBackgroundLabel(l10n, role),
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
                      l10n.aiPreviewTitle,
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
                            ? l10n.blockEditorAppearancePreviewEmpty
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
                          child: Text(l10n.blockEditorReset),
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
                          child: Text(l10n.aiApply),
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
        child: ListView.builder(
          itemCount: pages.length,
          itemBuilder: (context, i) {
            final p = pages[i];
            return ListTile(
              title: Text(p.title),
              onTap: () => Navigator.pop(ctx, p.id),
            );
          },
        ),
      ),
    );
  }

  Future<void> _editTemplateButtonLabel(String pageId, FolioBlock block) async {
    final data =
        FolioTemplateButtonData.tryParse(block.text) ??
        FolioTemplateButtonData.defaultNew();
    final labelCtrl = TextEditingController(text: data.label);
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.blockEditorTemplateButtonTitle),
        content: TextField(
          controller: labelCtrl,
          decoration: InputDecoration(
            labelText: l10n.blockEditorTemplateButtonFieldLabel,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final next = FolioTemplateButtonData(
        label: labelCtrl.text.trim().isEmpty
            ? l10n.blockEditorTemplateButtonDefaultLabel
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
    final l10n = AppLocalizations.of(context);
    return showFolioIconPicker(
      context: context,
      appSettings: widget.appSettings,
      title: l10n.blockEditorCalloutIconPickerTitle,
      helperText: l10n.blockEditorCalloutIconPickerHelper,
      fallbackText: '💡',
      quickIcons: const ['💡', '✅', '⚠️', '🚨', 'ℹ️', '📌', '🧠', '🚀'],
      customInputLabel: l10n.blockEditorIconPickerCustomEmoji,
      cancelLabel: l10n.cancel,
      saveLabel: l10n.save,
      removeLabel: l10n.remove,
      quickTabLabel: l10n.blockEditorIconPickerQuickTab,
      importedTabLabel: l10n.blockEditorIconPickerImportedTab,
      allEmojiTabLabel: l10n.blockEditorIconPickerAllTab,
      emptyImportedLabel: l10n.blockEditorIconPickerEmptyImported,
    );
  }

  String _t(String es, String en) {
    final isEs = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('es');
    return isEs ? es : en;
  }

  List<CodeLanguageOption> _codeLanguageOptionsForBlock(FolioBlock block) {
    final l10n = AppLocalizations.of(context);
    final out = List<CodeLanguageOption>.from(
      buildCodeLanguagePickerOptions(l10n),
    );
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
    return labelForCodeLanguageId(id, AppLocalizations.of(context));
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
            final sheetL10n = AppLocalizations.of(context);
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
                            sheetL10n.blockEditorCodeLanguageTitle,
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
                      sheetL10n.blockEditorCodeLanguageSubtitle,
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
            _buildCollabUploadProgressBadge(
              block.id,
              Theme.of(context),
              scheme,
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
    _s.removeBlocksIfMultiple(page.id, idsToDelete);
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
    _s.insertBlocksAfterMany(
      pageId: page.id,
      afterBlockId: blocks.last.id,
      blocks: clones,
    );
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
    return _buildBlockRowDelegated(
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

  @override
  void initState() {
    super.initState();
    _s.addListener(_onSession);
    _syncControllers();
  }

  @override
  void dispose() {
    _slashListScrollController.dispose();
    _mentionListScrollController.dispose();
    _blockListScrollController.dispose();
    _resolvedFileFutureByUrl.clear();
    _s.removeListener(_onSession);
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    final n = _controllers.length;
    final controllersToDispose = <TextEditingController>[];
    final focusToDispose = <FocusNode>[];
    for (var i = 0; i < n; i++) {
      if (i < _textListeners.length) {
        _controllers[i].removeListener(_textListeners[i]);
      }
      if (i < _focusDecorListeners.length) {
        _focusNodes[i].removeListener(_focusDecorListeners[i]);
      }
      // Evitar dispose mientras el FocusNode aún puede notificar cambios
      // (especialmente en Windows/Quill con callbacks de foco/IME pendientes).
      final fn = _focusNodes[i];
      if (fn.hasFocus) {
        fn.unfocus();
      }
      controllersToDispose.add(_controllers[i]);
      focusToDispose.add(fn);
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
    _selectionActiveBlockId = null;
    _mermaidEditingSourceIds.clear();
    _selectedBlockIds.clear();
    _selectionAnchorBlockId = null;
    _dragSelectionActive = false;
    _dragSelectionOriginBlockId = null;
    _dragSelectionBaseIds.clear();
    _collabUploadByBlockId.clear();
    _collabUploadTokenByBlockId.clear();
    _collabRoomKeyCache.clear();
    _collabRoomKeyInFlight.clear();
    _collabMediaCachePathByMediaId.clear();
    _collabUploadLastUiMsByBlockId.clear();
    _collabUploadLastProgressByBlockId.clear();
    _collabUploadLastEtaSecByBlockId.clear();
    _blockScrollKeys.clear();
    _tailTapTransientTouchedByBlockId.clear();
    final quillIds = _quillByBlockId.keys.toList();
    for (final id in quillIds) {
      // Evitar que Quill intente pedir teclado tras el teardown.
      final qc = _quillByBlockId[id];
      if (qc != null) {
        qc.skipRequestKeyboard = true;
      }
      _quillDebounceByBlockId[id]?.cancel();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Dispose diferido: deja que se drenen callbacks del frame actual.
      for (final c in controllersToDispose) {
        c.dispose();
      }
      for (final f in focusToDispose) {
        f.dispose();
      }
      for (final id in quillIds) {
        _disposeQuillFor(id);
      }
      _quillByBlockId.clear();
      _quillDebounceByBlockId.clear();
    });
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
      _pendingTailTransientBlockId = null;
      setState(() {});
      return;
    }
    if (!_ensureTrailingSentinel(page)) {
      return;
    }
    if (_boundPageId != null && _boundPageId != page.id) {
      final oldPageId = _boundPageId!;
      // Limpieza defensiva: si abandonamos una página dejando un bloque transient vacío,
      // lo eliminamos para que no se acumulen "bloques fantasma".
      for (final entry in _tailTapTransientTouchedByBlockId.entries) {
        final blockId = entry.key;
        final touched = entry.value;
        if (!touched) {
          _s.removeBlockIfMultiple(oldPageId, blockId);
        }
      }
      _selectedBlockIds.clear();
      _selectionAnchorBlockId = null;
    }
    _tailTapTransientTouchedByBlockId.removeWhere(
      (blockId, _) => !page.blocks.any((b) => b.id == blockId),
    );
    if (_pendingTailTransientBlockId != null &&
        !page.blocks.any((b) => b.id == _pendingTailTransientBlockId)) {
      _pendingTailTransientBlockId = null;
    }
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

    // Mantener sincronizados controllers que NO publican cambios al session
    // (payload blocks que actualizan `block.text` desde widgets internos).
    const skipTextSync = {
      'toggle',
      'column_list',
      'template_button',
      'toc',
      'breadcrumb',
      'child_page',
    };
    final n = math.min(page.blocks.length, _controllers.length);
    for (var i = 0; i < n; i++) {
      final b = page.blocks[i];
      if (!skipTextSync.contains(b.type)) continue;
      final c = _controllers[i];
      if (c.text != b.text) {
        // No preservamos selección: estos bloques no usan el controller para editar.
        c.value = TextEditingValue(
          text: b.text,
          selection: TextSelection.collapsed(offset: b.text.length),
        );
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
    _disposeQuillForBlocksNoLongerStylable(page);
    _reconcileStylableQuillDocumentsWithModel(page);
    setState(() {});
    _finalizePendingEditorFocus(page);
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
      if (_stylableBlockTypes.contains(b.type)) {
        // Asegurar controlador WYSIWYG y sincronizar desde el modelo si cambió
        // (p. ej. undo/redo o cambios remotos).
        final qc = _ensureQuillController(pageId: pid, block: b);
        final last = _quillLastMdByBlockId[bid];
        if (last != null && last != b.text) {
          if (_quillMarkdownNormalize(last) ==
              _quillMarkdownNormalize(b.text)) {
            _quillLastMdByBlockId[bid] = b.text;
          } else {
            final oldPlain = qc.document.toPlainText();
            final oldSel = qc.selection;
            qc.document = FolioMarkdownQuillCodec.markdownToDocument(b.text);
            _quillLastMdByBlockId[bid] = b.text;
            _quillDebounceByBlockId[bid]?.cancel();
            final newPlain = qc.document.toPlainText();
            if (newPlain == oldPlain && oldSel.isValid) {
              qc.updateSelection(oldSel, quill.ChangeSource.remote);
            } else if (oldSel.isValid) {
              final o = oldSel.baseOffset.clamp(0, oldPlain.length);
              final at = o.clamp(0, newPlain.length);
              qc.updateSelection(
                TextSelection.collapsed(offset: at),
                quill.ChangeSource.remote,
              );
            }
          }
        }
      }
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
        final idx = p.blocks.indexWhere((x) => x.id == bid);
        if (idx < 0) return;
        if (_tailTapTransientTouchedByBlockId.containsKey(bid) &&
            c.text.isNotEmpty) {
          _tailTapTransientTouchedByBlockId[bid] = true;
          if (_pendingTailTransientBlockId == bid) {
            _pendingTailTransientBlockId = null;
          }
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

        // Rastrear si este bloque tiene selección de texto activa.
        final hasSelection = c.selection.isValid && !c.selection.isCollapsed;
        final wasActive = _selectionActiveBlockId == bid;
        if (hasSelection && !wasActive) {
          _selectionActiveBlockId = bid;
          setState(() {});
        } else if (!hasSelection && wasActive) {
          _selectionActiveBlockId = null;
          setState(() {});
        }
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
        if (!fn.hasFocus) {
          // Limpiar selección activa al perder foco (si era este bloque).
          if (_selectionActiveBlockId == bid) {
            _selectionActiveBlockId = null;
          }
          // Flush inmediato de WYSIWYG al perder foco.
          if (_stylableBlockTypes.contains(b.type)) {
            final qc = _quillByBlockId[bid];
            if (qc != null) {
              _quillDebounceByBlockId[bid]?.cancel();
              final md = FolioMarkdownQuillCodec.documentToMarkdown(
                qc.document,
              );
              _quillLastMdByBlockId[bid] = md;
              _runWithShortcutsIgnored(() {
                _s.updateBlockText(pid, bid, md);
                final idx = _controllerBlockIds.indexOf(bid);
                if (idx >= 0 && idx < _controllers.length) {
                  final caret = qc.selection.baseOffset.clamp(0, md.length);
                  _controllers[idx].value = TextEditingValue(
                    text: md,
                    selection: TextSelection.collapsed(offset: caret),
                  );
                }
              });
            }
          }
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
                if (_pendingTailTransientBlockId == bid) {
                  _pendingTailTransientBlockId = null;
                }
                _s.removeBlockIfMultiple(pid, bid);
              });
            } else {
              _tailTapTransientTouchedByBlockId.remove(bid);
              if (_pendingTailTransientBlockId == bid) {
                _pendingTailTransientBlockId = null;
              }
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
      _pendingFocusIndex = idxToFocus;
      _pendingCursorOffset = offToFocus;
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

    var liveText = ctrl.text;
    var liveSel = ctrl.selection;
    final quillLive = _quillByBlockId[blockId];
    if (quillLive != null &&
        index >= 0 &&
        index < page.blocks.length &&
        _stylableBlockTypes.contains(page.blocks[index].type)) {
      liveText = quillLive.document.toPlainText();
      liveSel = quillLive.selection;
    }

    final slashFilter = _slashBlockId == blockId
        ? ((_slashFilterFromPlainTextAndSelection(liveText, liveSel)) ??
              _slashFilterFromBlockText(liveText))
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
        ? _mentionFilterFromSelection(liveText, liveSel)
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
              id: '${page.id}_${BlockEditorState._uuid.v4()}',
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

  bool _isValidCollabRoomId(String? raw) {
    final rid = raw?.trim();
    if (rid == null || rid.isEmpty) return false;
    if (RegExp(r'^[-—]+$').hasMatch(rid)) return false;
    return true;
  }

  bool _isCollabMediaUri(String raw) => raw.startsWith('collab-media://');

  ({String roomId, String mediaId})? _parseCollabMediaUri(String raw) {
    final u = Uri.tryParse(raw);
    if (u == null || u.scheme != 'collab-media') return null;
    final roomId = u.host.trim();
    final mediaId = u.pathSegments.isNotEmpty
        ? u.pathSegments.first.trim()
        : '';
    if (!_isValidCollabRoomId(roomId) || mediaId.isEmpty) return null;
    return (roomId: roomId, mediaId: mediaId);
  }

  Future<SecretKey?> _roomKeyForCollabRoom({
    required String roomId,
    required String joinCode,
  }) async {
    final cached = _collabRoomKeyCache[roomId];
    if (cached != null) return cached;

    final inFlight = _collabRoomKeyInFlight[roomId];
    if (inFlight != null) return inFlight;

    final future = (() async {
      final roomSnap = await FirebaseFirestore.instance
          .collection('collabRooms')
          .doc(roomId)
          .get();
      final room = roomSnap.data();
      if (room == null) return null;
      final e2eV = (room['e2eV'] as num?)?.toInt() ?? 0;
      if (e2eV != 1) return null;
      final wrapped = (room['wrappedRoomKey'] as String?)?.trim();
      if (wrapped == null || wrapped.isEmpty) return null;
      final key = await CollabE2eCrypto.unwrapRoomKeyB64(
        wrappedB64: wrapped,
        joinCodeNormalized: CollabE2eCrypto.normalizeJoinCode(joinCode),
        roomId: roomId,
      );
      _collabRoomKeyCache[roomId] = key;
      return key;
    })();

    _collabRoomKeyInFlight[roomId] = future;
    try {
      return await future;
    } finally {
      _collabRoomKeyInFlight.remove(roomId);
    }
  }

  bool _shouldEmitCollabUploadUi({
    required String blockId,
    required double? progress,
    required Duration? eta,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastMs = _collabUploadLastUiMsByBlockId[blockId];
    final nextProgress = progress ?? -1;
    final lastProgress = _collabUploadLastProgressByBlockId[blockId] ?? -2;
    final nextEtaSec = eta?.inSeconds ?? -1;
    final lastEtaSec = _collabUploadLastEtaSecByBlockId[blockId] ?? -2;

    final progressChangedEnough =
        progress == null ||
        lastProgress < 0 ||
        (nextProgress - lastProgress).abs() >= 0.02 ||
        nextProgress >= 1.0;
    final etaChanged = nextEtaSec != lastEtaSec;
    final enoughTimeElapsed = lastMs == null || (nowMs - lastMs) >= 180;

    if (!(progressChangedEnough || etaChanged || enoughTimeElapsed)) {
      return false;
    }

    _collabUploadLastUiMsByBlockId[blockId] = nowMs;
    _collabUploadLastProgressByBlockId[blockId] = nextProgress;
    _collabUploadLastEtaSecByBlockId[blockId] = nextEtaSec;
    return true;
  }

  void _enqueueCollabMediaUpload({
    required String pageId,
    required String blockId,
    required File localFile,
    required String mediaKind,
    required void Function(String uri) onCommittedUri,
  }) {
    unawaited(
      _uploadCollabMediaForBlock(
        pageId: pageId,
        blockId: blockId,
        file: localFile,
        mediaKind: mediaKind,
        onCommittedUri: onCommittedUri,
      ),
    );
  }

  Future<void> _uploadCollabMediaForBlock({
    required String pageId,
    required String blockId,
    required File file,
    required String mediaKind,
    required void Function(String uri) onCommittedUri,
  }) async {
    final page = _s.pages.firstWhereOrNull((p) => p.id == pageId);
    final roomId = page?.collabRoomId?.trim();
    final joinCode = page?.collabJoinCode?.trim();
    if (!_isValidCollabRoomId(roomId) || joinCode == null || joinCode.isEmpty) {
      return;
    }
    final fileSize = file.lengthSync();

    final token = _bumpCollabUploadToken(blockId);
    if (mounted) {
      setState(() {
        _collabUploadByBlockId[blockId] = const _CollabUploadProgress(
          encrypting: true,
        );
      });
    }

    try {
      final prep = await callFolioHttpsCallable('prepareCollabMediaUpload', {
        'roomId': roomId,
        'blockId': blockId,
        'mediaKind': mediaKind,
        'sizeBytes': fileSize,
      });
      if (prep is! Map) return;
      final mediaId = '${prep['mediaId'] ?? ''}'.trim();
      final storagePath = '${prep['storagePath'] ?? ''}'.trim();
      if (mediaId.isEmpty || storagePath.isEmpty) return;

      final roomKey = await _roomKeyForCollabRoom(
        roomId: roomId!,
        joinCode: joinCode,
      );
      if (roomKey == null) return;

      final plain = await file.readAsBytes();
      final cipher = await CollabE2eCrypto.encryptBinaryBytes(
        bytes: Uint8List.fromList(plain),
        roomKey: roomKey,
      );
      final ref = FirebaseStorage.instance.ref(storagePath);
      final startedAt = DateTime.now();
      final task = ref.putData(
        cipher,
        SettableMetadata(contentType: 'application/octet-stream'),
      );
      // Windows/Linux: los eventos de tarea llegan fuera del hilo de plataforma y
      // disparan [shell.cc] "non-platform thread" (flutterfire / Storage C++).
      final snapshotEventsSafe =
          defaultTargetPlatform != TargetPlatform.windows &&
          defaultTargetPlatform != TargetPlatform.linux;
      StreamSubscription<TaskSnapshot>? snapshotSub;
      if (snapshotEventsSafe) {
        snapshotSub = task.snapshotEvents.listen((snap) {
          if (!_isActiveCollabUploadToken(blockId, token) || !mounted) return;
          final total = snap.totalBytes <= 0 ? null : snap.totalBytes;
          final transferred = snap.bytesTransferred;
          final progress = total == null
              ? null
              : (transferred / total).clamp(0.0, 1.0);
          Duration? eta;
          if (total != null && transferred > 0 && transferred < total) {
            final elapsedMs = DateTime.now()
                .difference(startedAt)
                .inMilliseconds;
            if (elapsedMs > 0) {
              final rate = transferred / elapsedMs;
              if (rate > 0) {
                final remainingMs = ((total - transferred) / rate).round();
                eta = Duration(milliseconds: remainingMs.clamp(0, 36000000));
              }
            }
          }
          if (!_shouldEmitCollabUploadUi(
            blockId: blockId,
            progress: progress,
            eta: eta,
          )) {
            return;
          }
          setState(() {
            _collabUploadByBlockId[blockId] = _CollabUploadProgress(
              encrypting: false,
              progress: progress,
              eta: eta,
            );
          });
        });
      } else if (mounted) {
        setState(() {
          _collabUploadByBlockId[blockId] = const _CollabUploadProgress(
            encrypting: false,
            progress: null,
            eta: null,
          );
        });
      }
      try {
        await task;
      } finally {
        await snapshotSub?.cancel();
      }

      await callFolioHttpsCallable('commitCollabMediaUpload', {
        'roomId': roomId,
        'mediaId': mediaId,
        'blockId': blockId,
        'storagePath': storagePath,
        'mediaKind': mediaKind,
        'mimeType': '',
        'fileName': p.basename(file.path),
        'sizeBytes': fileSize,
      });
      if (!_isActiveCollabUploadToken(blockId, token)) return;
      final uri = 'collab-media://$roomId/$mediaId';
      onCommittedUri(uri);
      if (mounted) {
        setState(() {
          _collabUploadByBlockId.remove(blockId);
        });
      }
      _collabUploadLastUiMsByBlockId.remove(blockId);
      _collabUploadLastProgressByBlockId.remove(blockId);
      _collabUploadLastEtaSecByBlockId.remove(blockId);
    } catch (e) {
      if (!_isActiveCollabUploadToken(blockId, token) || !mounted) return;
      setState(() {
        _collabUploadByBlockId[blockId] = _CollabUploadProgress(
          encrypting: false,
          progress: null,
          eta: null,
          error: '$e',
        );
      });
      _collabUploadLastUiMsByBlockId.remove(blockId);
      _collabUploadLastProgressByBlockId.remove(blockId);
      _collabUploadLastEtaSecByBlockId.remove(blockId);
    }
  }

  Future<File?> _resolveCollabMediaFile(String rawUrl) async {
    final parsed = _parseCollabMediaUri(rawUrl);
    if (parsed == null) return null;

    final page = _s.selectedPage;
    final joinCode = page?.collabJoinCode?.trim();
    if (joinCode == null || joinCode.isEmpty) return null;

    final cached = await _findCachedCollabMediaFile(parsed.mediaId);
    if (cached != null) return cached;

    try {
      final mediaSnap = await FirebaseFirestore.instance
          .collection('collabRooms')
          .doc(parsed.roomId)
          .collection('media')
          .doc(parsed.mediaId)
          .get();
      final media = mediaSnap.data();
      if (media == null) return null;
      final storagePath = (media['storagePath'] as String?)?.trim();
      if (storagePath == null || storagePath.isEmpty) return null;

      final roomKey = await _roomKeyForCollabRoom(
        roomId: parsed.roomId,
        joinCode: joinCode,
      );
      if (roomKey == null) return null;

      final data = await FirebaseStorage.instance
          .ref(storagePath)
          .getData(80 * 1024 * 1024);
      if (data == null || data.isEmpty) return null;
      final clear = await CollabE2eCrypto.decryptBinaryBytes(
        cipherBytes: Uint8List.fromList(data),
        roomKey: roomKey,
      );

      final cacheDir = await _collabMediaCacheDir();
      final fileName = (media['fileName'] as String?)?.trim();
      final ext = (fileName != null && fileName.isNotEmpty)
          ? p.extension(fileName)
          : '.bin';
      final out = File(p.join(cacheDir.path, '${parsed.mediaId}$ext'));
      await out.writeAsBytes(clear, flush: true);
      _collabMediaCachePathByMediaId[parsed.mediaId] = out.path;
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _collabMediaCacheDir() async {
    final vault = await VaultPaths.vaultDirectory();
    final cacheDir = Directory(
      p.join(vault.path, VaultPaths.attachmentsDirName, '.collab_cache'),
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<File?> _findCachedCollabMediaFile(String mediaId) async {
    final knownPath = _collabMediaCachePathByMediaId[mediaId];
    if (knownPath != null) {
      final known = File(knownPath);
      if (await known.exists() && await known.length() > 0) {
        return known;
      }
      _collabMediaCachePathByMediaId.remove(mediaId);
    }

    final cacheDir = await _collabMediaCacheDir();
    final defaultBin = File(p.join(cacheDir.path, '$mediaId.bin'));
    if (await defaultBin.exists() && await defaultBin.length() > 0) {
      _collabMediaCachePathByMediaId[mediaId] = defaultBin.path;
      return defaultBin;
    }

    await for (final e in cacheDir.list(followLinks: false)) {
      if (e is! File) continue;
      if (p.basenameWithoutExtension(e.path) != mediaId) continue;
      if (await e.length() <= 0) continue;
      _collabMediaCachePathByMediaId[mediaId] = e.path;
      return e;
    }
    return null;
  }

  int _bumpCollabUploadToken(String blockId) {
    final next = (_collabUploadTokenByBlockId[blockId] ?? 0) + 1;
    _collabUploadTokenByBlockId[blockId] = next;
    return next;
  }

  bool _isActiveCollabUploadToken(String blockId, int token) {
    return _collabUploadTokenByBlockId[blockId] == token;
  }

  String _formatEta(Duration? eta) {
    if (eta == null) return '--:--';
    final secs = eta.inSeconds.clamp(0, 359999);
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _buildCollabUploadProgressBadge(
    String blockId,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final u = _collabUploadByBlockId[blockId];
    if (u == null) return const SizedBox.shrink();
    if (u.error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          _t(
            'Error al subir a sala: ${u.error}',
            'Room upload failed: ${u.error}',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
        ),
      );
    }
    final progress = u.progress;
    final pct = progress == null
        ? _t('Preparando cifrado…', 'Preparing encryption...')
        : _t(
            'Subiendo ${(progress * 100).toStringAsFixed(0)}% · ETA ${_formatEta(u.eta)}',
            'Uploading ${(progress * 100).toStringAsFixed(0)}% · ETA ${_formatEta(u.eta)}',
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(FolioRadius.xs),
            child: LinearProgressIndicator(value: progress),
          ),
          const SizedBox(height: 4),
          Text(
            pct,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
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
      final result = await FilePicker.pickFiles(
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
    _enqueueCollabMediaUpload(
      pageId: pageId,
      blockId: blockId,
      localFile: file,
      mediaKind: 'image',
      onCommittedUri: (uri) {
        _ignoreShortcuts = true;
        _s.updateBlockText(pageId, blockId, uri);
        if (index < _controllers.length) {
          _controllers[index].value = TextEditingValue(
            text: uri,
            selection: TextSelection.collapsed(offset: uri.length),
          );
        }
        _ignoreShortcuts = false;
      },
    );
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
    final result = await FilePicker.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final rel = await VaultPaths.importAttachmentFile(
        file,
        preserveExtension: true,
        preserveFileName: true,
      );
      _s.updateBlockUrl(pageId, blockId, rel);
      setState(() {});
      _enqueueCollabMediaUpload(
        pageId: pageId,
        blockId: blockId,
        localFile: file,
        mediaKind: 'file',
        onCommittedUri: (uri) => _s.updateBlockUrl(pageId, blockId, uri),
      );
    }
  }

  Future<void> _pickVideoForBlock(String pageId, String blockId) async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final rel = await VaultPaths.importAttachmentFile(
        file,
        preserveExtension: true,
        preserveFileName: true,
      );
      _s.updateBlockUrl(pageId, blockId, rel);
      setState(() {});
      _enqueueCollabMediaUpload(
        pageId: pageId,
        blockId: blockId,
        localFile: file,
        mediaKind: 'video',
        onCommittedUri: (uri) => _s.updateBlockUrl(pageId, blockId, uri),
      );
    }
  }

  Future<void> _pickAudioForBlock(String pageId, String blockId) async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final rel = await VaultPaths.importAttachmentFile(
        file,
        preserveExtension: true,
        preserveFileName: true,
      );
      _s.updateBlockUrl(pageId, blockId, rel);
      setState(() {});
      _enqueueCollabMediaUpload(
        pageId: pageId,
        blockId: blockId,
        localFile: file,
        mediaKind: 'audio',
        onCommittedUri: (uri) => _s.updateBlockUrl(pageId, blockId, uri),
      );
    }
  }

  void _clearBlockUrl(String pageId, String blockId) {
    _s.updateBlockUrl(pageId, blockId, null);
    if (mounted) setState(() {});
  }

  Future<File?> _resolveBlockUrlFile(String? rawUrl) async {
    final raw0 = rawUrl?.trim();
    if (raw0 == null || raw0.isEmpty) return null;
    if (_isCollabMediaUri(raw0)) {
      return _resolveCollabMediaFile(raw0);
    }
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
    // Límite simple para evitar crecimiento indefinido del cache en sesiones largas.
    if (_resolvedFileFutureByUrl.length > 500) {
      _resolvedFileFutureByUrl.remove(_resolvedFileFutureByUrl.keys.first);
    }
    return _resolvedFileFutureByUrl.putIfAbsent(
      key,
      () => _resolveBlockUrlFile(key),
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
        _onBlockMenuChosen(v, menuContext, page, b, index);
      },
      itemBuilder: (ctx) =>
          _buildBlockMenuItems(ctx, page: page, b: b, index: index),
    );
  }

  void _onBlockMenuChosen(
    String v,
    BuildContext menuContext,
    FolioPage page,
    FolioBlock b,
    int index,
  ) {
    if (v == 'del') {
      if (page.blocks.length > 1) {
        if (b.type == 'meeting_note') {
          final idx = page.blocks.indexWhere((it) => it.id == b.id);
          if (idx > 0) {
            _pendingFocusIndex = idx - 1;
            _pendingCursorOffset = page.blocks[idx - 1].text.length;
          } else if (page.blocks.length > 1) {
            _pendingFocusIndex = 0;
            _pendingCursorOffset = 0;
          }
          _s.removeBlockIfMultiple(page.id, b.id);
        } else {
          _deleteSelectedBlocks(page, _selectedIdsForAction(page, b.id));
        }
      } else {
        // Si es el ultimo bloque, lo dejamos como parrafo vacio
        // para no romper la regla de pagina no vacia.
        _s.changeBlockType(page.id, b.id, 'paragraph');
        _s.updateBlockText(page.id, b.id, '');
        _s.updateBlockUrl(page.id, b.id, null);
        final j = _controllerBlockIds.indexOf(b.id);
        if (j >= 0 && j < _controllers.length) {
          _ignoreShortcuts = true;
          _controllers[j].clear();
          _ignoreShortcuts = false;
        }
        _pendingFocusBlockId = b.id;
        _pendingCursorOffset = 0;
        if (mounted) setState(() {});
      }
    } else if (v == 'ai_rewrite') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final c = TextEditingController();
        final rewriteL10n = AppLocalizations.of(menuContext);
        final go = await showDialog<bool>(
          context: menuContext,
          builder: (ctx) => AlertDialog(
            title: Text(rewriteL10n.aiRewriteDialogTitle),
            content: TextField(
              controller: c,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: rewriteL10n.aiInstructionHint,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(rewriteL10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(rewriteL10n.aiApply),
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
          if (!menuContext.mounted) return;
          final previewL10n = AppLocalizations.of(menuContext);
          final accept = await showDialog<bool>(
            context: menuContext,
            builder: (ctx) {
              return AlertDialog(
                title: Text(previewL10n.aiPreviewTitle),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SingleChildScrollView(
                    child: FolioAiTypewriterMessage(
                      fullText: preview.text,
                      style:
                          baseStyle ??
                          TextStyle(color: scheme.onSurface, height: 1.35),
                      selectable: true,
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(previewL10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(previewL10n.aiApply),
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
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.aiGenericErrorWithReason('$e'))),
          );
        }
      });
    } else if (v == 'pick_type') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final choice = await _openBlockTypePicker(menuContext);
        if (!mounted || choice == null) return;
        final blockId = b.id;
        var preservedOff = 0;
        final i0 = page.blocks.indexWhere((x) => x.id == blockId);
        if (i0 >= 0 && i0 < _controllers.length) {
          if (_stylableBlockTypes.contains(b.type)) {
            final qc = _quillByBlockId[blockId];
            if (qc != null && qc.selection.isValid) {
              preservedOff = qc.selection.baseOffset.clamp(
                0,
                qc.document.toPlainText().length,
              );
            }
          } else {
            final c = _controllers[i0];
            if (c.selection.isValid) {
              preservedOff = c.selection.baseOffset.clamp(0, c.text.length);
            }
          }
        }
        _pendingFocusBlockId = blockId;
        _pendingCursorOffset = preservedOff;
        _s.changeBlockType(page.id, blockId, choice);
        final p2 = _s.selectedPage;
        if (p2 != null && mounted) {
          final j = p2.blocks.indexWhere((x) => x.id == blockId);
          if (j >= 0 && j < _controllers.length) {
            final nb = p2.blocks[j];
            final len = nb.text.length;
            final off = preservedOff.clamp(0, len);
            _ignoreShortcuts = true;
            _controllers[j].value = TextEditingValue(
              text: nb.text,
              selection: TextSelection.collapsed(offset: off),
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
        d.rows.add(
          FolioDbRow(id: '${page.id}_r_${BlockEditorState._uuid.v4()}'),
        );
      });
    } else if (v == 'db_col_add') {
      _mutateDatabase(page.id, b.id, index, (d) {
        d.properties.add(
          FolioDbProperty(
            id: 'p_${BlockEditorState._uuid.v4()}',
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
    } else if (v == 'meeting_copy_transcript') {
      final text = b.text.trim();
      if (text.isNotEmpty) {
        unawaited(Clipboard.setData(ClipboardData(text: text)));
      }
    } else if (v == 'meeting_send_to_ai') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _openMeetingNoteAiDialog(menuContext, page, b);
      });
    } else if (v == 'callout_pick_icon') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final emoji = await _pickEmoji(menuContext);
        if (!mounted || emoji == null) return;
        _s.updateBlockIcon(page.id, b.id, emoji);
      });
    } else if (v == 'callout_tone_info') {
      _s.updateBlockIcon(page.id, b.id, '💡');
    } else if (v == 'callout_tone_success') {
      _s.updateBlockIcon(page.id, b.id, '✅');
    } else if (v == 'callout_tone_warning') {
      _s.updateBlockIcon(page.id, b.id, '⚠️');
    } else if (v == 'callout_tone_error') {
      _s.updateBlockIcon(page.id, b.id, '🚨');
    } else if (v == 'callout_tone_note') {
      _s.updateBlockIcon(page.id, b.id, 'ℹ️');
    }
  }

  List<PopupMenuEntry<String>> _buildBlockMenuItems(
    BuildContext ctx, {
    required FolioPage page,
    required FolioBlock b,
    required int index,
  }) {
    PopupMenuItem<String> item(
      BuildContext c, {
      required String value,
      required IconData icon,
      required String label,
      Color? iconColor,
    }) {
      final scheme = Theme.of(c).colorScheme;
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

    final data = b.type == 'table' ? FolioTableData.tryParse(b.text) : null;
    final db = b.type == 'database' ? FolioDatabaseData.tryParse(b.text) : null;
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
    final l10n = AppLocalizations.of(ctx);
    return [
      if (_s.aiEnabled)
        item(
          ctx,
          value: 'ai_rewrite',
          icon: Icons.auto_fix_high_rounded,
          label: l10n.blockEditorMenuRewriteWithAi,
        ),
      if (index > 0)
        item(
          ctx,
          value: 'up',
          icon: Icons.keyboard_arrow_up_rounded,
          label: l10n.blockEditorMenuMoveUp,
        ),
      if (index < page.blocks.length - 1)
        item(
          ctx,
          value: 'down',
          icon: Icons.keyboard_arrow_down_rounded,
          label: l10n.blockEditorMenuMoveDown,
        ),
      item(
        ctx,
        value: 'dup',
        icon: Icons.copy_all_rounded,
        label: l10n.blockEditorMenuDuplicateBlock,
      ),
      if (_blockSupportsAppearance(b))
        item(
          ctx,
          value: 'appearance',
          icon: Icons.palette_outlined,
          label: l10n.blockEditorMenuAppearance,
        ),
      if (b.type == 'callout') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'callout_pick_icon',
          icon: Icons.emoji_emotions_outlined,
          label: l10n.blockEditorMenuCalloutIcon,
        ),
        item(
          ctx,
          value: 'callout_tone_info',
          icon: Icons.lightbulb_outline_rounded,
          label: l10n.blockEditorCalloutMenuType(l10n.calloutTypeInfo),
        ),
        item(
          ctx,
          value: 'callout_tone_success',
          icon: Icons.task_alt_rounded,
          label: l10n.blockEditorCalloutMenuType(l10n.calloutTypeSuccess),
        ),
        item(
          ctx,
          value: 'callout_tone_warning',
          icon: Icons.warning_amber_rounded,
          label: l10n.blockEditorCalloutMenuType(l10n.calloutTypeWarning),
        ),
        item(
          ctx,
          value: 'callout_tone_error',
          icon: Icons.report_problem_outlined,
          label: l10n.blockEditorCalloutMenuType(l10n.calloutTypeError),
        ),
        item(
          ctx,
          value: 'callout_tone_note',
          icon: Icons.info_outline_rounded,
          label: l10n.blockEditorCalloutMenuType(l10n.calloutTypeNote),
        ),
      ],
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
          label: l10n.blockEditorCopyLink,
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
          label: l10n.blockEditorMenuCreateSubpage,
        ),
        item(
          ctx,
          value: 'child_link',
          icon: Icons.link_rounded,
          label: l10n.blockEditorMenuLinkPage,
        ),
        if (isChildLinked)
          item(
            ctx,
            value: 'child_open',
            icon: Icons.open_in_new_rounded,
            label: l10n.blockEditorMenuOpenSubpage,
          ),
      ],
      if (b.type == 'image') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'img_pick',
          icon: Icons.image_rounded,
          label: l10n.blockEditorMenuPickImage,
        ),
        if (b.text.isNotEmpty)
          item(
            ctx,
            value: 'img_clear',
            icon: Icons.delete_outline_rounded,
            label: l10n.blockEditorMenuRemoveImage,
          ),
      ],
      if (b.type == 'code') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'code_lang',
          icon: Icons.translate_rounded,
          label: l10n.blockEditorMenuCodeLanguage,
        ),
      ],
      if (b.type == 'mermaid') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'mermaid_edit',
          icon: Icons.edit_note_rounded,
          label: l10n.blockEditorMenuEditDiagram,
        ),
        if (_mermaidEditingSourceIds.contains(b.id))
          item(
            ctx,
            value: 'mermaid_hide',
            icon: Icons.visibility_rounded,
            label: l10n.blockEditorMenuBackToPreview,
          ),
      ],
      if (b.type == 'file') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'file_pick',
          icon: Icons.attach_file_rounded,
          label: l10n.blockEditorMenuChangeFile,
        ),
        if ((b.url ?? '').trim().isNotEmpty)
          item(
            ctx,
            value: 'file_clear',
            icon: Icons.delete_outline_rounded,
            label: l10n.blockEditorMenuRemoveFile,
          ),
      ],
      if (b.type == 'video') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'video_pick',
          icon: Icons.video_settings_rounded,
          label: l10n.blockEditorMenuChangeVideo,
        ),
        if ((b.url ?? '').trim().isNotEmpty)
          item(
            ctx,
            value: 'video_clear',
            icon: Icons.delete_outline_rounded,
            label: l10n.blockEditorMenuRemoveVideo,
          ),
      ],
      if (b.type == 'audio') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'audio_pick',
          icon: Icons.audio_file_rounded,
          label: l10n.blockEditorMenuChangeAudio,
        ),
        if ((b.url ?? '').trim().isNotEmpty)
          item(
            ctx,
            value: 'audio_clear',
            icon: Icons.delete_outline_rounded,
            label: l10n.blockEditorMenuRemoveAudio,
          ),
      ],
      if (b.type == 'template_button') ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'template_edit_label',
          icon: Icons.title_rounded,
          label: l10n.blockEditorMenuEditLabel,
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
      if (b.type == 'meeting_note') ...[
        const PopupMenuDivider(),
        if (b.text.trim().isNotEmpty)
          item(
            ctx,
            value: 'meeting_copy_transcript',
            icon: Icons.copy_rounded,
            label: AppLocalizations.of(ctx).meetingNoteCopyTranscript,
          ),
        if (_s.aiEnabled)
          item(
            ctx,
            value: 'meeting_send_to_ai',
            icon: Icons.auto_fix_high_rounded,
            label: AppLocalizations.of(ctx).meetingNoteSendToAi,
          ),
      ],
      if (b.type == 'table' && data != null) ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'table_row_add',
          icon: Icons.table_rows_rounded,
          label: l10n.blockEditorMenuAddRow,
        ),
        if (rows > 1)
          item(
            ctx,
            value: 'table_row_rem',
            icon: Icons.table_rows_outlined,
            label: l10n.blockEditorMenuRemoveLastRow,
          ),
        item(
          ctx,
          value: 'table_col_add',
          icon: Icons.view_column_rounded,
          label: l10n.blockEditorMenuAddColumn,
        ),
        if (cols > 1)
          item(
            ctx,
            value: 'table_col_rem',
            icon: Icons.view_column_outlined,
            label: l10n.blockEditorMenuRemoveLastColumn,
          ),
      ],
      if (b.type == 'database' && db != null) ...[
        const PopupMenuDivider(),
        item(
          ctx,
          value: 'db_row_add',
          icon: Icons.playlist_add_rounded,
          label: l10n.blockEditorMenuAddRow,
        ),
        item(
          ctx,
          value: 'db_col_add',
          icon: Icons.add_chart_rounded,
          label: l10n.blockEditorMenuAddProperty,
        ),
      ],
      const PopupMenuDivider(),
      item(
        ctx,
        value: 'pick_type',
        icon: Icons.auto_awesome_motion_rounded,
        iconColor: Theme.of(ctx).colorScheme.primary,
        label: l10n.blockEditorMenuChangeBlockType,
      ),
      const PopupMenuDivider(),
      item(
        ctx,
        value: 'del',
        icon: Icons.delete_forever_rounded,
        iconColor: Theme.of(ctx).colorScheme.error,
        label: l10n.blockEditorMenuDeleteBlock,
      ),
    ];
  }

  Future<void> _showBlockContextMenuAtGlobal(
    Offset globalPosition,
    BuildContext menuContext,
    FolioPage page,
    FolioBlock b,
    int index,
  ) async {
    if (!mounted || readOnlyMode) return;
    final navigatorContext = context;
    final items = _buildBlockMenuItems(
      navigatorContext,
      page: page,
      b: b,
      index: index,
    );
    setState(() => _menuOpenBlockId = b.id);
    final overlayBox =
        Overlay.of(navigatorContext).context.findRenderObject()! as RenderBox;
    final overlayRect = overlayBox.localToGlobal(Offset.zero) & overlayBox.size;
    final menuRect = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      overlayRect,
    );
    final choice = await showMenu<String>(
      context: navigatorContext,
      position: menuRect,
      items: items,
    );
    if (!mounted) return;
    if (_menuOpenBlockId == b.id) {
      setState(() => _menuOpenBlockId = null);
    }
    if (choice == null) return;
    if (!menuContext.mounted) return;
    _onBlockMenuChosen(choice, menuContext, page, b, index);
  }

  // ─── Meeting note IA ────────────────────────────────────────────────────────

  Future<void> _openMeetingNoteAiDialog(
    BuildContext dialogContext,
    FolioPage page,
    FolioBlock b,
  ) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final hasAudio = (b.url ?? '').trim().isNotEmpty;

    // Estado mutable del diálogo
    var payload = hasAudio
        ? _MeetingAiPayload.both
        : _MeetingAiPayload.transcript;
    final instructionCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: Text(l10n.meetingNoteSendToAi),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.meetingNoteAiPayloadLabel,
                      style: Theme.of(ctx).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.meetingNoteAiPayloadTranscript),
                          selected: payload == _MeetingAiPayload.transcript,
                          onSelected: (_) => setS(
                            () => payload = _MeetingAiPayload.transcript,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(l10n.meetingNoteAiPayloadAudio),
                          selected: payload == _MeetingAiPayload.audio,
                          onSelected: !hasAudio
                              ? null
                              : (_) => setS(
                                  () => payload = _MeetingAiPayload.audio,
                                ),
                        ),
                        ChoiceChip(
                          label: Text(l10n.meetingNoteAiPayloadBoth),
                          selected: payload == _MeetingAiPayload.both,
                          onSelected: !hasAudio
                              ? null
                              : (_) => setS(
                                  () => payload = _MeetingAiPayload.both,
                                ),
                        ),
                      ],
                    ),
                    if (!hasAudio &&
                        payload != _MeetingAiPayload.transcript) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.meetingNoteAiNoAudio,
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: instructionCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.meetingNoteAiInstruction,
                        hintText: l10n.meetingNoteAiInstructionHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      autofocus: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );

    final instruction = instructionCtrl.text.trim();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => instructionCtrl.dispose(),
    );

    if (confirmed != true || instruction.isEmpty || !mounted) return;

    try {
      // Resolver attachments según payload
      List<AiFileAttachment> attachments = [];
      String? overrideBlockText;

      if (payload == _MeetingAiPayload.audio ||
          payload == _MeetingAiPayload.both) {
        final relUrl = (b.url ?? '').trim();
        if (relUrl.isNotEmpty) {
          final vault = await VaultPaths.vaultDirectory();
          final audioPath = p.join(
            vault.path,
            relUrl.replaceAll('/', p.separator),
          );
          attachments = await _s.buildAiAttachmentsFromPaths([audioPath]);
        }
      }

      if (payload == _MeetingAiPayload.audio) {
        // Solo audio: indicamos a la IA que use el archivo adjunto
        overrideBlockText =
            '[Audio adjunto — analiza el archivo de audio proporcionado]';
      }

      if (!mounted) return;

      final preview = await _s.previewRewriteBlockWithAi(
        pageId: page.id,
        blockId: b.id,
        instruction: instruction,
        attachments: attachments,
        overrideBlockText: overrideBlockText,
      );

      if (!mounted) return;

      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final baseStyle = theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface,
        height: 1.35,
      );

      final meetingPreviewL10n = AppLocalizations.of(context);
      final accept = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(meetingPreviewL10n.aiPreviewTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              child: FolioAiTypewriterMessage(
                fullText: preview.text,
                style:
                    baseStyle ??
                    TextStyle(color: scheme.onSurface, height: 1.35),
                selectable: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(meetingPreviewL10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(meetingPreviewL10n.aiApply),
            ),
          ],
        ),
      );

      if (accept != true || !mounted) return;
      await _applyTypewriterToBlock(
        pageId: page.id,
        blockId: b.id,
        fullText: preview.text,
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aiGenericErrorWithReason('$e'))),
      );
    }
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
    final l10n = AppLocalizations.of(context);
    final enterHint = widget.appSettings.enterCreatesNewBlock
        ? l10n.blockEditorEnterHintNewBlock
        : l10n.blockEditorEnterHintNewLine;
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
                    ? l10n.blockEditorShortcutsHintMobile(enterHint)
                    : l10n.blockEditorShortcutsHintDesktop(enterHint),
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
                        l10n.blockEditorSelectedBlocksBanner(selectedCount),
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
                      label: Text(l10n.blockEditorDuplicate),
                    ),
                    TextButton.icon(
                      onPressed: page.blocks.length > 1
                          ? () => _deleteSelectedBlocks(
                              page,
                              _selectedBlockIds.toList(),
                            )
                          : null,
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: Text(l10n.delete),
                    ),
                    IconButton(
                      onPressed: _clearBlockSelection,
                      tooltip: l10n.blockEditorClearSelectionTooltip,
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
                onTapDown: null,
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
                      final isLast = index == page.blocks.length - 1;
                      final hideTrailingSentinel =
                          page.blocks.length > 1 &&
                          isLast &&
                          _isTrailingSentinel(b) &&
                          ctrl.text.trim().isEmpty &&
                          !focus.hasFocus;
                      if (hideTrailingSentinel) {
                        return KeyedSubtree(
                          key: ValueKey('block_row_${b.id}'),
                          child: const SizedBox.shrink(),
                        );
                      }
                      final style = _styleFor(b.type, theme.textTheme);
                      final selected = _isBlockSelected(b.id);
                      final showActionsBaseline =
                          selected ||
                          focus.hasFocus ||
                          _menuOpenBlockId == b.id ||
                          (!androidPhoneLayout && _selectedBlockIds.length > 1);
                      return KeyedSubtree(
                        key: ValueKey('block_row_${b.id}'),
                        child: RepaintBoundary(
                          child: _BlockListRow(
                            editor: this,
                            readOnlyMode: readOnlyMode,
                            androidPhoneLayout: androidPhoneLayout,
                            scheme: scheme,
                            page: page,
                            block: b,
                            index: index,
                            ctrl: ctrl,
                            focus: focus,
                            style: style,
                            selected: selected,
                            showActionsBaseline: showActionsBaseline,
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
}
