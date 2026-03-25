import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_settings.dart';
import '../../app/folio_in_app_shortcuts.dart';
import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_feedback.dart';
import '../../models/folio_page.dart';
import '../../models/block.dart';
import '../../models/folio_columns_data.dart';
import '../../models/folio_template_button_data.dart';
import '../../models/folio_toggle_data.dart';
import '../../services/ai/ai_types.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/run2doc/run2doc_markdown_codec.dart';
import '../../session/vault_session.dart';
import '../settings/settings_page.dart';
import 'widgets/ai_typing_indicator.dart';
import 'widgets/block_editor.dart';
import 'widgets/page_history_sheet.dart';
import 'widgets/mermaid_markdown_builder.dart';
import 'widgets/sidebar.dart';
import 'widgets/workspace_editor_surface.dart';
import 'widgets/workspace_shell.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    super.key,
    required this.session,
    required this.appSettings,
    required this.onOpenSearch,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final VoidCallback onOpenSearch;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final TextEditingController _titleController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _chatInputController = TextEditingController();
  final FocusNode _chatInputFocusNode = FocusNode();
  List<String> _aiAttachmentPaths = [];
  late String _attachmentsBoundChatId;
  bool _aiChatBusy = false;
  AiTokenUsage? _lastChatTokenUsage;
  double _aiPanelWidth = 360;
  bool _aiPanelCollapsed = false;
  bool _showQuillWorkspaceTour = false;
  final Set<String> _expandedThoughtMessageKeys = <String>{};
  final ScrollController _aiChatScrollController = ScrollController();
  String? _lastAiChatIdForScroll;
  int _lastAiChatMessageCount = -1;

  VaultSession get _s => widget.session;
  AiChatThreadData get _activeChat => _s.activeAiChat;

  void _snack(String message, {bool error = false}) {
    if (!mounted || message.trim().isEmpty) return;
    showFolioSnack(context, message, error: error);
  }

  String _suggestMarkdownFileName(String title) {
    final base = title.trim().isEmpty ? 'page' : title.trim();
    final safe = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${safe.isEmpty ? 'page' : safe}.md';
  }

  Future<FolioMarkdownImportMode?> _askMarkdownImportMode() {
    final page = _s.selectedPage;
    if (page == null) {
      return Future.value(FolioMarkdownImportMode.newPage);
    }
    return showDialog<FolioMarkdownImportMode>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: const Text('Importar Markdown'),
        content: const Text('Elige cómo quieres aplicar el archivo Markdown.'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, FolioMarkdownImportMode.newPage),
            child: const Text('Página nueva'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, FolioMarkdownImportMode.appendToCurrentPage),
            child: const Text('Anexar a la actual'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, FolioMarkdownImportMode.replaceCurrentPage),
            child: const Text('Reemplazar actual'),
          ),
        ],
      ),
    );
  }

  Future<void> _importMarkdownFile() async {
    if (_s.state != VaultFlowState.unlocked) return;
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'markdown'],
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final path = pick.files.single.path;
    if (path == null || path.trim().isEmpty) {
      _snack('No se pudo leer la ruta del archivo.');
      return;
    }
    final mode = await _askMarkdownImportMode();
    if (mode == null) return;
    try {
      final markdown = await File(path).readAsString();
      final title = pick.files.single.name.replaceFirst(
        RegExp(r'\.(md|markdown)$', caseSensitive: false),
        '',
      );
      final result = _s.importMarkdownDocument(
        markdown,
        title: title,
        mode: mode,
      );
      if (!mounted) return;
      _snack(
        'Markdown importado: ${result.pageTitle} (${result.blockCount} bloques).',
      );
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo importar el Markdown: $e');
    }
  }

  Future<void> _exportCurrentPageToMarkdown() async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    final destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Exportar página a Markdown',
      fileName: _suggestMarkdownFileName(page.title),
      type: FileType.custom,
      allowedExtensions: const ['md'],
    );
    if (destination == null || destination.trim().isEmpty) return;
    try {
      final markdown = _s.exportPageAsMarkdown(page.id);
      await File(destination).writeAsString(markdown);
      if (!mounted) return;
      _snack('Página exportada a Markdown.');
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo exportar la página: $e');
    }
  }

  Widget _buildMarkdownMessage({
    required BuildContext context,
    required String content,
    required bool isUser,
    required Color textColor,
  }) {
    final normalizedContent = _normalizeHtmlForChat(content);
    final base = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: textColor, height: 1.35);
    final code = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: textColor, fontFamily: 'monospace');
    final sheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: base,
      h1: base?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      h2: base?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      h3: base?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      blockquote: base,
      code: code,
      codeblockDecoration: BoxDecoration(
        color: Colors.black.withValues(alpha: isUser ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: textColor.withValues(alpha: 0.28)),
        ),
      ),
      listBullet: base,
    );
    return MarkdownBody(
      data: normalizedContent,
      selectable: true,
      softLineBreak: true,
      shrinkWrap: true,
      styleSheet: sheet,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      builders: {'pre': FolioMermaidMarkdownBuilder()},
    );
  }

  ({String? thought, String body}) _splitAgentThought(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return (thought: null, body: '');
    final lines = normalized.split('\n');
    if (lines.length < 2) return (thought: null, body: normalized);
    final first = lines[0].trimLeft();
    final second = lines[1].trimLeft();
    final hasDecision =
        first.startsWith('🧠') ||
        first.toLowerCase().contains('**decisión del agente:**') ||
        first.toLowerCase().contains('**decisión de quill:**') ||
        first.toLowerCase().contains('**agent decision:**') ||
        first.toLowerCase().contains("**quill's decision:**");
    final hasReason =
        second.startsWith('💡') ||
        second.toLowerCase().contains('**motivo:**') ||
        second.toLowerCase().contains('**reason:**');
    if (!hasDecision || !hasReason) {
      return (thought: null, body: normalized);
    }
    var bodyStart = 2;
    while (bodyStart < lines.length && lines[bodyStart].trim().isEmpty) {
      bodyStart++;
    }
    final thought = '${lines[0].trimRight()}\n${lines[1].trimRight()}'.trim();
    final body = lines.sublist(bodyStart).join('\n').trim();
    return (thought: thought, body: body);
  }

  String _normalizeHtmlForChat(String raw) {
    final lower = raw.toLowerCase();
    final looksHtml =
        lower.contains('<html') ||
        lower.contains('<body') ||
        lower.contains('<p>') ||
        lower.contains('<h1') ||
        lower.contains('<table');
    if (!looksHtml) return raw;
    var out = raw;
    out = out.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false, dotAll: true),
      '\n',
    );
    out = out.replaceAllMapped(
      RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true),
      (m) => '\n# ${_stripHtmlTagsForChat(m.group(1) ?? '')}\n',
    );
    out = out.replaceAllMapped(
      RegExp(r'<h2[^>]*>(.*?)</h2>', caseSensitive: false, dotAll: true),
      (m) => '\n## ${_stripHtmlTagsForChat(m.group(1) ?? '')}\n',
    );
    out = out.replaceAllMapped(
      RegExp(r'<h3[^>]*>(.*?)</h3>', caseSensitive: false, dotAll: true),
      (m) => '\n### ${_stripHtmlTagsForChat(m.group(1) ?? '')}\n',
    );
    out = out.replaceAllMapped(
      RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true),
      (m) => '\n${_stripHtmlTagsForChat(m.group(1) ?? '')}\n',
    );
    out = out.replaceAllMapped(
      RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
      (m) => '- ${_stripHtmlTagsForChat(m.group(1) ?? '')}\n',
    );
    out = out.replaceAll(
      RegExp(r'<[^>]+>', caseSensitive: false, dotAll: true),
      '',
    );
    out = out.replaceAll('&nbsp;', ' ');
    out = out.replaceAll('&amp;', '&');
    out = out.replaceAll('&lt;', '<');
    out = out.replaceAll('&gt;', '>');
    out = out.replaceAll('&quot;', '"');
    return out.trim();
  }

  String _stripHtmlTagsForChat(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false, dotAll: true), '')
        .trim();
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _attachmentsBoundChatId = _s.activeAiChat.id;
    _aiAttachmentPaths = List<String>.from(_s.activeAiChat.attachmentPaths);
    _s.addListener(_onSession);
    widget.appSettings.addListener(_onAppSettings);
    HardwareKeyboard.instance.addHandler(_onHardwareKeyEvent);
    _syncTitleFromSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowQuillWorkspaceTour();
    });
  }

  @override
  void dispose() {
    _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
    HardwareKeyboard.instance.removeHandler(_onHardwareKeyEvent);
    widget.appSettings.removeListener(_onAppSettings);
    _s.removeListener(_onSession);
    _titleController.dispose();
    _chatInputController.dispose();
    _chatInputFocusNode.dispose();
    _aiChatScrollController.dispose();
    super.dispose();
  }

  void _scheduleAiChatScrollToBottom() {
    void scrollNow() {
      if (!mounted || !_aiChatScrollController.hasClients) return;
      final pos = _aiChatScrollController.position;
      _aiChatScrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollNow();
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollNow());
    });
  }

  void _onSession() {
    if (!mounted) return;
    if (_s.activeAiChat.id != _attachmentsBoundChatId) {
      _attachmentsBoundChatId = _s.activeAiChat.id;
      _aiAttachmentPaths = List<String>.from(_s.activeAiChat.attachmentPaths);
    }
    final chat = _s.activeAiChat;
    final threadChanged = chat.id != _lastAiChatIdForScroll;
    final countChanged = chat.messages.length != _lastAiChatMessageCount;
    _lastAiChatIdForScroll = chat.id;
    _lastAiChatMessageCount = chat.messages.length;
    _syncTitleFromSession();
    setState(() {});
    if (countChanged || threadChanged) {
      _scheduleAiChatScrollToBottom();
    }
  }

  void _onAppSettings() {
    _maybeShowQuillWorkspaceTour();
    if (mounted) setState(() {});
  }

  bool _matchesActivator(SingleActivator activator, KeyEvent event) {
    if (event.logicalKey != activator.trigger) return false;
    final keyboard = HardwareKeyboard.instance;
    return activator.accepts(event, keyboard);
  }

  bool _onHardwareKeyEvent(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;

    final a = widget.appSettings;
    final bindings = <({SingleActivator activator, VoidCallback action})>[
      (
        activator: a.inAppShortcut(FolioInAppShortcut.search),
        action: () {
          if (_shouldHandleShortcut(FolioInAppShortcut.search)) {
            widget.onOpenSearch();
          }
        },
      ),
      (
        activator: a.inAppShortcut(FolioInAppShortcut.newPage),
        action: () {
          if (_shouldHandleShortcut(FolioInAppShortcut.newPage)) {
            _s.addPage(parentId: null);
          }
        },
      ),
      (
        activator: a.inAppShortcut(FolioInAppShortcut.settings),
        action: () {
          if (_shouldHandleShortcut(FolioInAppShortcut.settings)) {
            _openSettings();
          }
        },
      ),
      (
        activator: a.inAppShortcut(FolioInAppShortcut.lock),
        action: () {
          if (_shouldHandleShortcut(FolioInAppShortcut.lock)) {
            _s.lock();
          }
        },
      ),
      (
        activator: a.inAppShortcut(FolioInAppShortcut.pageNext),
        action: () {
          if (_shouldHandleShortcut(FolioInAppShortcut.pageNext)) {
            _selectAdjacentPage(1);
          }
        },
      ),
      (
        activator: a.inAppShortcut(FolioInAppShortcut.pagePrev),
        action: () {
          if (_shouldHandleShortcut(FolioInAppShortcut.pagePrev)) {
            _selectAdjacentPage(-1);
          }
        },
      ),
      (
        activator: a.inAppShortcut(FolioInAppShortcut.closePage),
        action: () {
          if (_shouldHandleShortcut(FolioInAppShortcut.closePage)) {
            _s.clearSelectedPage();
          }
        },
      ),
      (
        activator: const SingleActivator(
          LogicalKeyboardKey.keyF,
          control: true,
        ),
        action: () {
          if (_shouldHandleShortcut(FolioInAppShortcut.search)) {
            widget.onOpenSearch();
          }
        },
      ),
      (
        activator: const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
        ),
        action: () {
          _s.undoPageEdits();
        },
      ),
      (
        activator: const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ),
        action: () {
          _s.redoPageEdits();
        },
      ),
      (
        activator: const SingleActivator(
          LogicalKeyboardKey.keyY,
          control: true,
        ),
        action: () {
          _s.redoPageEdits();
        },
      ),
    ];

    for (final binding in bindings) {
      if (_matchesActivator(binding.activator, event)) {
        binding.action();
        return true;
      }
    }
    return false;
  }

  void _maybeShowQuillWorkspaceTour() {
    if (!mounted) return;
    if (_showQuillWorkspaceTour) return;
    if (widget.appSettings.hasSeenQuillWorkspaceTour) return;
    setState(() {
      if (widget.appSettings.isAiRuntimeEnabled && _s.aiEnabled) {
        _aiPanelCollapsed = false;
      }
      _showQuillWorkspaceTour = true;
    });
  }

  Future<void> _dismissQuillWorkspaceTour() async {
    if (!_showQuillWorkspaceTour) return;
    setState(() => _showQuillWorkspaceTour = false);
    await widget.appSettings.setHasSeenQuillWorkspaceTour(true);
  }

  void _useQuillTourPrompt(String prompt) {
    setState(() {
      if (widget.appSettings.isAiRuntimeEnabled && _s.aiEnabled) {
        _aiPanelCollapsed = false;
      }
      _chatInputController.value = TextEditingValue(
        text: prompt,
        selection: TextSelection.collapsed(offset: prompt.length),
      );
    });
    _chatInputFocusNode.requestFocus();
  }

  Widget _buildBetaBanner(ColorScheme scheme, AppLocalizations l10n) {
    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.science_outlined,
              size: 20,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.appBetaBannerMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                  height: 1.35,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  unawaited(widget.appSettings.setBetaBannerDismissed(true)),
              child: Text(l10n.appBetaBannerDismiss),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuillWorkspaceTourCard(
    ThemeData theme,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    final quillReady = widget.appSettings.isAiRuntimeEnabled && _s.aiEnabled;
    Widget promptChip(String prompt) {
      return ActionChip(
        onPressed: quillReady ? () => _useQuillTourPrompt(prompt) : null,
        avatar: Icon(
          quillReady ? Icons.arrow_upward_rounded : Icons.lightbulb_outline,
          size: 16,
          color: quillReady
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
        label: Text(prompt),
        backgroundColor: quillReady
            ? scheme.primaryContainer.withValues(alpha: FolioAlpha.thumbHover)
            : scheme.surfaceContainerHigh,
        labelStyle: theme.textTheme.bodySmall?.copyWith(
          color: quillReady
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: FolioAlpha.panel),
        ),
      );
    }

    return Material(
      elevation: 10,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(FolioRadius.xl),
      shadowColor: scheme.shadow.withValues(alpha: FolioAlpha.soft),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FolioRadius.xl),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: FolioAlpha.panel),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(
                      alpha: FolioAlpha.thumbHover,
                    ),
                    borderRadius: BorderRadius.circular(FolioRadius.lg),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.quillWorkspaceTourTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quillReady
                            ? l10n.quillWorkspaceTourBodyReady
                            : l10n.quillWorkspaceTourBodyUnavailable,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.quillTourDismiss,
                  onPressed: _dismissQuillWorkspaceTour,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              l10n.quillWorkspaceTourPointsTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• ${l10n.quillWorkspaceTourPointOne}\n'
              '• ${l10n.quillWorkspaceTourPointTwo}\n'
              '• ${l10n.quillWorkspaceTourPointThree}',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.quillWorkspaceTourExamplesTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                promptChip(l10n.quillWorkspaceTourExampleOne),
                promptChip(l10n.quillWorkspaceTourExampleTwo),
                promptChip(l10n.quillWorkspaceTourExampleThree),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!quillReady)
                  TextButton(
                    onPressed: _openSettings,
                    child: Text(l10n.settings),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _dismissQuillWorkspaceTour,
                  child: Text(l10n.quillTourDismiss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _syncTitleFromSession() {
    final p = _s.selectedPage;
    final next = p?.title ?? '';
    if (_titleController.text != next) {
      _titleController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) =>
            SettingsPage(session: _s, appSettings: widget.appSettings),
      ),
    );
  }

  bool _isTextInputFocused() {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final focusedWidget = focusedContext?.widget;
    return focusedWidget is EditableText;
  }

  bool _shouldHandleShortcut(FolioInAppShortcut shortcut) {
    if (!_isTextInputFocused()) return true;
    switch (shortcut) {
      case FolioInAppShortcut.search:
      case FolioInAppShortcut.newPage:
      case FolioInAppShortcut.settings:
      case FolioInAppShortcut.lock:
      case FolioInAppShortcut.pageNext:
      case FolioInAppShortcut.pagePrev:
        return true;
      case FolioInAppShortcut.closePage:
        return false;
    }
  }

  void _selectAdjacentPage(int delta) {
    final pages = _s.pages;
    if (pages.isEmpty) return;
    final currentId = _s.selectedPageId;
    final currentIndex = pages.indexWhere((p) => p.id == currentId);
    if (currentIndex < 0) {
      _s.selectPage(pages.first.id);
      return;
    }
    final next = (currentIndex + delta).clamp(0, pages.length - 1);
    if (next != currentIndex) {
      _s.selectPage(pages[next].id);
    }
  }

  void _openPageHistoryScreen() {
    final page = _s.selectedPage;
    if (page == null) return;
    openPageHistoryScreen(context: context, session: _s, page: page);
  }

  List<String> _buildPagePathSegments(FolioPage? page) {
    if (page == null) return const <String>[];
    final byId = <String, FolioPage>{for (final p in _s.pages) p.id: p};
    final chain = <String>[];
    final visited = <String>{};
    FolioPage? current = page;
    while (current != null && !visited.contains(current.id)) {
      visited.add(current.id);
      chain.add(
        current.title.trim().isEmpty ? 'Untitled' : current.title.trim(),
      );
      final parentId = current.parentId;
      current = parentId == null ? null : byId[parentId];
    }
    return chain.reversed.toList(growable: false);
  }

  Future<String?> _showBlockTypePicker({required bool compact}) {
    if (compact) {
      return showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const BlockTypePickerSheet(catalog: blockTypeCatalog),
      );
    }
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(FolioSpace.xl),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 620,
          height: 720,
          child: const BlockTypePickerSheet(catalog: blockTypeCatalog),
        ),
      ),
    );
  }

  void _appendBlockToPage(FolioPage page, String type) {
    var text = '';
    bool? expanded;
    String? codeLanguage;
    if (type == 'toggle') {
      text = FolioToggleData.empty().encode();
      expanded = false;
    } else if (type == 'template_button') {
      text = FolioTemplateButtonData.defaultNew().encode();
    } else if (type == 'column_list') {
      text = FolioColumnsData.empty().encode();
    } else if (type == 'equation') {
      text = r'E = mc^2';
      codeLanguage = 'plaintext';
    }
    if (type == 'code') codeLanguage = 'dart';
    _s.appendBlock(
      pageId: page.id,
      block: FolioBlock(
        id: '${page.id}_${const Uuid().v4()}',
        type: type,
        text: text,
        checked: type == 'todo' ? false : null,
        expanded: expanded,
        codeLanguage: codeLanguage,
      ),
    );
  }

  Future<void> _addBlockToCurrentPage({required bool compact}) async {
    final page = _s.selectedPage;
    if (page == null) return;
    final type = await _showBlockTypePicker(compact: compact);
    if (type == null || !mounted) return;
    _appendBlockToPage(page, type);
  }

  Future<List<AiFileAttachment>> _collectAiAttachments() async {
    return _s.buildAiAttachmentsFromPaths(_aiAttachmentPaths);
  }

  Future<void> _pickAiAttachments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    for (final f in result.files) {
      final path = f.path;
      if (path == null || path.trim().isEmpty) continue;
      if (!_aiAttachmentPaths.contains(path)) {
        _aiAttachmentPaths.add(path);
      }
    }
    if (mounted) {
      setState(() {});
      _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
    }
  }

  String _formatTokenCount(int? n) {
    if (n == null) return '—';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(2)}k';
    return n.toString();
  }

  void _insertNewlineInChatInput() {
    final c = _chatInputController;
    final sel = c.selection;
    if (!sel.isValid) {
      c.text = '${c.text}\n';
      c.selection = TextSelection.collapsed(offset: c.text.length);
      return;
    }
    final t = c.text;
    final start = sel.start;
    final end = sel.end;
    final newText = t.replaceRange(start, end, '\n');
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  KeyEventResult _onChatInputKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed) {
      _insertNewlineInChatInput();
      return KeyEventResult.handled;
    }
    unawaited(_sendAiChat());
    return KeyEventResult.handled;
  }

  Future<void> _sendAiChat() async {
    if (_aiChatBusy) return;
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _aiChatBusy = true);
    _scheduleAiChatScrollToBottom();
    try {
      await _s.pingAi();
    } catch (e) {
      if (mounted) {
        setState(() => _aiChatBusy = false);
        final l10n = AppLocalizations.of(context);
        final msg = e is AiServiceUnreachableException
            ? l10n.aiServiceUnreachable
            : l10n.aiErrorWithDetails(e);
        _snack(msg, error: true);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _chatInputController.clear();
    });
    _s.appendMessageToActiveAiChat(AiChatMessage(role: 'user', content: text));
    try {
      final outcome = await _runAiFromChat(text, _activeChat.messages);
      if (!mounted) return;
      setState(() => _lastChatTokenUsage = outcome.usage);
      _s.appendMessageToActiveAiChat(
        AiChatMessage(role: 'assistant', content: outcome.reply),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _snack(l10n.aiErrorWithDetails(e), error: true);
    } finally {
      if (mounted) {
        setState(() => _aiChatBusy = false);
      }
    }
  }

  Future<AgentChatOutcome> _runAiFromChat(
    String text,
    List<AiChatMessage> threadMessages,
  ) async {
    final t = text.trim();
    final languageCode = Localizations.localeOf(context).languageCode;
    final attachments = await _collectAiAttachments();
    return _s.agentChatWithAi(
      messages: threadMessages,
      prompt: t,
      scopePageId: _s.selectedPageId,
      includePageContext: _activeChat.includePageContext,
      contextPageIds: _activeChat.contextPageIds,
      attachments: attachments,
      languageCode: languageCode,
    );
  }

  String _aiPanelContextSubtitle(AppLocalizations l10n) {
    final chat = _activeChat;
    if (!chat.includePageContext) return l10n.aiChatContextDisabledSubtitle;
    if (chat.contextPageIds.isEmpty) {
      final t = _s.selectedPage?.title;
      if (t != null && t.isNotEmpty) {
        return l10n.aiChatContextUsesCurrentPage(t);
      }
      return l10n.aiNoPageSelected;
    }
    if (chat.contextPageIds.length == 1) {
      final id = chat.contextPageIds.first;
      for (final p in _s.pages) {
        if (p.id == id) return p.title;
      }
      return l10n.aiChatContextOnePageFallback;
    }
    return l10n.aiChatContextNPages(chat.contextPageIds.length);
  }

  Future<void> _showRenameActiveChatDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: _s.activeAiChat.title);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(l10n.aiRenameChatDialogTitle),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: l10n.aiRenameChatLabel),
              maxLength: 80,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                final t = controller.text.trim();
                if (t.isNotEmpty) Navigator.pop(ctx, t);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isEmpty) return;
                  Navigator.pop(ctx, t);
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      );
      if (!mounted || result == null) return;
      _s.renameAiChatAt(_s.aiActiveChatIndex, result);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openAiContextPagesDialog() async {
    final l10n = AppLocalizations.of(context);
    final selected = Set<String>.from(_activeChat.contextPageIds);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(l10n.aiChatContextPagesDialogTitle),
              content: SizedBox(
                width: 420,
                height: 400,
                child: ListView(
                  children: _s.pages.map((p) {
                    return CheckboxListTile(
                      value: selected.contains(p.id),
                      onChanged: (v) {
                        setDialogState(() {
                          if (v == true) {
                            selected.add(p.id);
                          } else {
                            selected.remove(p.id);
                          }
                        });
                      },
                      title: Text(
                        p.title.isEmpty ? l10n.untitledFallback : p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() => selected.clear());
                  },
                  child: Text(l10n.aiChatContextPagesClear),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    _s.setActiveAiChatContextPageIds(selected.toList());
                    Navigator.pop(ctx);
                  },
                  child: Text(l10n.aiChatContextPagesApply),
                ),
              ],
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  void _createNewChat() {
    _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
    setState(() => _lastChatTokenUsage = null);
    _s.createNewAiChat();
  }

  void _deleteActiveChat() {
    _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
    setState(() => _lastChatTokenUsage = null);
    _s.deleteActiveAiChat();
  }

  Widget _buildAiTypingRow(
    ThemeData theme,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    final textColor = scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              size: 16,
              color: scheme.onSecondaryContainer,
            ),
          ),
          Flexible(
            child: Semantics(
              label: l10n.aiTypingSemantics,
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(
                    FolioRadius.lg,
                  ).copyWith(topLeft: Radius.zero),
                ),
                child: FolioAiTypingIndicator(
                  color: textColor.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiChatContextRow(
    ThemeData theme,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    final u = _lastChatTokenUsage;
    final window = math.max(1, widget.appSettings.aiContextWindowTokens);
    final prompt = u?.promptTokens;
    if (prompt == null) {
      return Text(
        l10n.aiContextUsageUnavailable,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    final frac = math.min(1.0, prompt / window);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: l10n.aiContextUsageTooltip(window),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(FolioRadius.xs),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 5,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.aiContextUsageSummary(
            _formatTokenCount(prompt),
            _formatTokenCount(u!.completionTokens),
          ),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAiPanel(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(
                  FolioRadius.xl,
                ), // fully rounded top section
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                l10n.aiAssistantTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                l10n.aiBetaBadge,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _aiPanelContextSubtitle(l10n),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton(
                              tooltip: l10n.aiChatPageContextTooltip,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              icon: Icon(
                                _activeChat.includePageContext
                                    ? Icons.menu_book_rounded
                                    : Icons.menu_book_outlined,
                                size: 22,
                                color: _activeChat.includePageContext
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant.withValues(
                                        alpha: 0.55,
                                      ),
                              ),
                              onPressed: () =>
                                  _s.setActiveAiChatIncludePageContext(
                                    !_activeChat.includePageContext,
                                  ),
                            ),
                            IconButton(
                              tooltip: l10n.aiChatChooseContextPagesTooltip,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              icon: Icon(
                                Icons.library_books_outlined,
                                size: 22,
                                color: _activeChat.includePageContext
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurfaceVariant.withValues(
                                        alpha: 0.35,
                                      ),
                              ),
                              onPressed: _activeChat.includePageContext
                                  ? _openAiContextPagesDialog
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _aiPanelCollapsed
                        ? l10n.aiExpand
                        : l10n.aiCollapse,
                    onPressed: () =>
                        setState(() => _aiPanelCollapsed = !_aiPanelCollapsed),
                    icon: Icon(
                      _aiPanelCollapsed
                          ? Icons.keyboard_arrow_left_rounded
                          : Icons.keyboard_arrow_right_rounded,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _s.aiChatThreads.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final active = i == _s.aiActiveChatIndex;
                        return ChoiceChip(
                          label: Text(
                            _s.aiChatThreads[i].title,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: active,
                          onSelected: (_) {
                            _s.syncActiveAiChatAttachmentPaths(
                              _aiAttachmentPaths,
                            );
                            setState(() => _lastChatTokenUsage = null);
                            _s.selectAiChat(i);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: l10n.aiRenameChatTooltip,
                    onPressed: _showRenameActiveChatDialog,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: l10n.aiDeleteCurrentChat,
                    onPressed: _deleteActiveChat,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  const SizedBox(width: 2),
                  FilledButton.tonal(
                    onPressed: _createNewChat,
                    child: Text(l10n.aiNewChat),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Builder(
                builder: (context) {
                  final msgs = _activeChat.messages;
                  final showChatList = msgs.isNotEmpty || _aiChatBusy;
                  if (!showChatList) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.aiChatEmptyHint,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ),
                    );
                  }
                  final typingExtra = _aiChatBusy ? 1 : 0;
                  return ListView.builder(
                    controller: _aiChatScrollController,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    itemCount: msgs.length + typingExtra,
                    itemBuilder: (context, i) {
                      if (_aiChatBusy && i == msgs.length) {
                        return _buildAiTypingRow(theme, scheme, l10n);
                      }
                      final m = msgs[i];
                      final isUser = m.role == 'user';
                      final split = _splitAgentThought(m.content);
                      final thought = split.thought;
                      final bodyContent = split.body;
                      final msgKey = '${_activeChat.id}#$i';
                      final alwaysShowThought =
                          widget.appSettings.aiAlwaysShowThought;
                      final thoughtExpanded =
                          alwaysShowThought ||
                          _expandedThoughtMessageKeys.contains(msgKey);
                      final bubbleColor = isUser
                          ? scheme.primaryContainer
                          : Colors.transparent;
                      final textColor = isUser
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: isUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment
                              .start, // ChatGPT style is top aligned
                          children: [
                            if (!isUser)
                              Container(
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(
                                  right: 12,
                                  top: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  shape: BoxShape.circle, // Circular avatar
                                ),
                                child: Icon(
                                  Icons.smart_toy_outlined,
                                  size: 16,
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isUser ? 16 : 4,
                                  vertical: isUser ? 12 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: bubbleColor,
                                  borderRadius: BorderRadius.circular(20)
                                      .copyWith(
                                        bottomRight: isUser
                                            ? Radius.zero
                                            : null,
                                        topLeft: !isUser ? Radius.zero : null,
                                      ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (!isUser &&
                                        thought != null &&
                                        thought.isNotEmpty)
                                      InkWell(
                                        onTap: alwaysShowThought
                                            ? null
                                            : () {
                                                setState(() {
                                                  if (_expandedThoughtMessageKeys
                                                      .contains(msgKey)) {
                                                    _expandedThoughtMessageKeys
                                                        .remove(msgKey);
                                                  } else {
                                                    _expandedThoughtMessageKeys
                                                        .add(msgKey);
                                                  }
                                                });
                                              },
                                        child: Row(
                                          children: [
                                            Icon(
                                              thoughtExpanded
                                                  ? Icons
                                                        .keyboard_arrow_down_rounded
                                                  : Icons
                                                        .keyboard_arrow_right_rounded,
                                              size: 18,
                                              color: textColor.withValues(
                                                alpha: 0.9,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                ).aiAgentThought,
                                                style: theme
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: textColor
                                                          .withValues(
                                                            alpha: 0.9,
                                                          ),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (!isUser &&
                                        thought != null &&
                                        thought.isNotEmpty &&
                                        thoughtExpanded) ...[
                                      const SizedBox(height: 6),
                                      _buildMarkdownMessage(
                                        context: context,
                                        content: thought,
                                        isUser: isUser,
                                        textColor: textColor,
                                      ),
                                      const SizedBox(height: 8),
                                      Divider(
                                        height: 1,
                                        color: textColor.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    _buildMarkdownMessage(
                                      context: context,
                                      content: bodyContent.isEmpty
                                          ? m.content
                                          : bodyContent,
                                      isUser: isUser,
                                      textColor: textColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAiChatContextRow(theme, scheme, l10n),
                  const SizedBox(height: 4),
                  Text(
                    l10n.aiChatKeyboardHint,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_aiAttachmentPaths.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          top: 4,
                        ),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _aiAttachmentPaths
                              .map(
                                (p) => InputChip(
                                  label: Text(p.split('\\').last),
                                  onDeleted: () {
                                    setState(
                                      () => _aiAttachmentPaths.remove(p),
                                    );
                                    _s.syncActiveAiChatAttachmentPaths(
                                      _aiAttachmentPaths,
                                    );
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _pickAiAttachments,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          tooltip: l10n.aiAttach,
                          padding: const EdgeInsets.all(12),
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Focus(
                              onKeyEvent: _onChatInputKey,
                              child: TextField(
                                focusNode: _chatInputFocusNode,
                                controller: _chatInputController,
                                minLines: 1,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: l10n.aiInputHint,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _aiChatBusy ? null : _sendAiChat,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          child: _aiChatBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 20,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final page = _s.selectedPage;

    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < FolioDesktop.compactBreakpoint;
    final medium = width < FolioDesktop.mediumBreakpoint;
    final isAiPanelVisible =
        !compact &&
        widget.appSettings.isAiRuntimeEnabled &&
        _s.aiEnabled &&
        !_aiPanelCollapsed;
    final sidePanelWidth = medium
        ? FolioDesktop.sidebarWidth
        : FolioDesktop.sidebarWideWidth;
    final sidePanel = Material(
      color: scheme.surfaceContainerLow,
      child: Sidebar(
        session: _s,
        onSearch: widget.onOpenSearch,
        onOpenSettings: _openSettings,
        onLock: () => _s.lock(),
      ),
    );
    final a = widget.appSettings;
    final shortcutBindings = <ShortcutActivator, VoidCallback>{
      a.inAppShortcut(FolioInAppShortcut.search): () {
        if (_shouldHandleShortcut(FolioInAppShortcut.search)) {
          widget.onOpenSearch();
        }
      },
      a.inAppShortcut(FolioInAppShortcut.newPage): () {
        if (_shouldHandleShortcut(FolioInAppShortcut.newPage)) {
          _s.addPage(parentId: null);
        }
      },
      a.inAppShortcut(FolioInAppShortcut.settings): () {
        if (_shouldHandleShortcut(FolioInAppShortcut.settings)) {
          _openSettings();
        }
      },
      a.inAppShortcut(FolioInAppShortcut.lock): () {
        if (_shouldHandleShortcut(FolioInAppShortcut.lock)) _s.lock();
      },
      a.inAppShortcut(FolioInAppShortcut.pageNext): () {
        if (_shouldHandleShortcut(FolioInAppShortcut.pageNext)) {
          _selectAdjacentPage(1);
        }
      },
      a.inAppShortcut(FolioInAppShortcut.pagePrev): () {
        if (_shouldHandleShortcut(FolioInAppShortcut.pagePrev)) {
          _selectAdjacentPage(-1);
        }
      },
      a.inAppShortcut(FolioInAppShortcut.closePage): () {
        if (_shouldHandleShortcut(FolioInAppShortcut.closePage)) {
          _s.clearSelectedPage();
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
        _s.undoPageEdits();
      },
      const SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      ): () {
        _s.redoPageEdits();
      },
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
        _s.redoPageEdits();
      },
    };
    const altSearch = SingleActivator(LogicalKeyboardKey.keyF, control: true);
    if (a.inAppShortcut(FolioInAppShortcut.search) != altSearch) {
      shortcutBindings[altSearch] = () {
        if (_shouldHandleShortcut(FolioInAppShortcut.search)) {
          widget.onOpenSearch();
        }
      };
    }
    final appBarActions = <Widget>[
      ...() {
        final canToggleAi =
            widget.appSettings.isAiRuntimeEnabled && _s.aiEnabled;
        final entries = <_WorkspaceActionEntry>[
          if (!compact && page != null)
            _WorkspaceActionEntry(
              id: 'add_block',
              label: l10n.addBlock,
              icon: Icons.add_rounded,
              onPressed: () => _addBlockToCurrentPage(compact: false),
              forcePrimary: true,
            ),
          _WorkspaceActionEntry(
            id: 'import_md',
            label: 'Importar Markdown',
            icon: Icons.file_upload_outlined,
            onPressed: _importMarkdownFile,
            forcePrimary: true,
          ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'export_md',
              label: 'Exportar Markdown',
              icon: Icons.file_download_outlined,
              onPressed: _exportCurrentPageToMarkdown,
            ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'history',
              label: l10n.pageHistory,
              icon: Icons.history_rounded,
              onPressed: _openPageHistoryScreen,
            ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'close_page',
              label: l10n.closeCurrentPage,
              icon: Icons.tab_unselected_rounded,
              onPressed: _s.clearSelectedPage,
            ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'undo_page_edit',
              label: 'Deshacer (Ctrl+Z)',
              icon: Icons.undo_rounded,
              onPressed: () => _s.undoPageEdits(),
              enabled: _s.canUndoSelectedPage,
              forceOverflow: true,
            ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'redo_page_edit',
              label: 'Rehacer (Ctrl+Y)',
              icon: Icons.redo_rounded,
              onPressed: () => _s.redoPageEdits(),
              enabled: _s.canRedoSelectedPage,
              forceOverflow: true,
            ),
          if (canToggleAi)
            _WorkspaceActionEntry(
              id: 'toggle_ai',
              label: _aiPanelCollapsed ? l10n.aiShowPanel : l10n.aiHidePanel,
              icon: _aiPanelCollapsed
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.close_fullscreen_rounded,
              onPressed: () =>
                  setState(() => _aiPanelCollapsed = !_aiPanelCollapsed),
              forcePrimary: true,
            ),
        ];

        final useOverflow = !compact && width < 1420;
        final primaryBudget = width >= 1660 ? 7 : (width >= 1420 ? 5 : 3);
        final primary = <_WorkspaceActionEntry>[];
        final overflow = <_WorkspaceActionEntry>[];

        for (final action in entries) {
          final shouldKeepPrimary =
              !action.forceOverflow &&
              (!useOverflow ||
                  action.forcePrimary ||
                  primary.length < primaryBudget);
          if (shouldKeepPrimary) {
            primary.add(action);
          } else {
            overflow.add(action);
          }
        }

        final widgets = <Widget>[
          ...primary.map(
            (action) => IconButton(
              tooltip: action.label,
              icon: Icon(action.icon),
              onPressed: action.enabled ? action.onPressed : null,
            ),
          ),
          if (overflow.isNotEmpty)
            PopupMenuButton<_WorkspaceActionEntry>(
              tooltip: 'Más acciones',
              icon: const Icon(Icons.more_horiz_rounded),
              itemBuilder: (context) => overflow
                  .map(
                    (action) => PopupMenuItem<_WorkspaceActionEntry>(
                      value: action,
                      enabled: action.enabled,
                      child: Row(
                        children: [
                          Icon(action.icon, size: 18),
                          const SizedBox(width: FolioSpace.sm),
                          Expanded(child: Text(action.label)),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
              onSelected: (action) => action.onPressed(),
            ),
        ];

        if (_s.hasPendingDiskSave || _s.isPersistingToDisk) {
          widgets.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(end: FolioSpace.xs),
              child: Center(
                child: Tooltip(
                  message: _s.isPersistingToDisk
                      ? l10n.savingVaultTooltip
                      : l10n.autosaveSoonTooltip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FolioSpace.sm,
                      vertical: FolioSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(FolioRadius.xl),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_s.isPersistingToDisk)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          )
                        else
                          Icon(
                            Icons.save_outlined,
                            size: 20,
                            color: scheme.primary.withValues(alpha: 0.85),
                          ),
                        const SizedBox(width: FolioSpace.xs),
                        Text(
                          _s.isPersistingToDisk
                              ? l10n.saveInProgress
                              : l10n.savePending,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
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
        return widgets;
      }(),
    ];
    final editorContent = WorkspaceEditorSurface(
      compact: compact,
      page: page,
      pagePath: _buildPagePathSegments(page),
      titleController: _titleController,
      editorMaxWidth: widget.appSettings.editorContentWidth,
      onTitleChanged: (value) {
        if (page != null && page.id == _s.selectedPageId) {
          _s.renamePage(page.id, value);
        }
      },
      onCreatePage: () => _s.addPage(parentId: null),
      editor: page == null
          ? const SizedBox.shrink()
          : BlockEditor(
              key: ValueKey('${page.id}-${_s.contentEpoch}'),
              session: _s,
            ),
    );
    return CallbackShortcuts(
      bindings: shortcutBindings,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: scheme.surfaceContainerLow,
        drawer: compact
            ? Drawer(
                width: width.clamp(260, 340),
                child: SafeArea(child: sidePanel),
              )
            : null,
        appBar: WorkspaceTopAppBar(
          title: l10n.appTitle,
          compact: compact,
          actions: appBarActions,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        body: WorkspaceBodyShell(
          compact: compact,
          sidePanelWidth: sidePanelWidth,
          sidePanel: sidePanel,
          editorContent: editorContent,
          showAiPanel: isAiPanelVisible,
          aiPanelWidth: _aiPanelWidth,
          onResizeAiPanel: (delta) {
            final screenW = MediaQuery.sizeOf(context).width;
            final maxW = (screenW * 0.55).clamp(340.0, 720.0);
            setState(() {
              _aiPanelWidth = (_aiPanelWidth - delta).clamp(
                FolioDesktop.aiPanelWidth,
                maxW,
              );
            });
          },
          scheme: scheme,
          betaBanner: widget.appSettings.shouldShowBetaBanner
              ? _buildBetaBanner(scheme, l10n)
              : null,
          aiPanel: isAiPanelVisible ? _buildAiPanel(context) : null,
          overlay: _showQuillWorkspaceTour
              ? _buildQuillWorkspaceTourCard(theme, scheme, l10n)
              : null,
        ),
        floatingActionButton: compact && page != null
            ? Padding(
                padding: EdgeInsets.only(
                  right: isAiPanelVisible ? _aiPanelWidth + 18 : 0,
                ),
                child: FloatingActionButton(
                  onPressed: () => _addBlockToCurrentPage(compact: true),
                  child: const Icon(Icons.add_rounded),
                ),
              )
            : null,
      ),
    );
  }
}

class _WorkspaceActionEntry {
  const _WorkspaceActionEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.forcePrimary = false,
    this.enabled = true,
    this.forceOverflow = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool forcePrimary;
  final bool enabled;
  final bool forceOverflow;
}
