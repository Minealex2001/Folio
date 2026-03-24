import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_settings.dart';
import '../../app/ui_tokens.dart';
import '../../models/folio_page.dart';
import '../../models/block.dart';
import '../../services/ai/ai_types.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../session/vault_session.dart';
import '../settings/settings_page.dart';
import 'widgets/block_editor.dart';
import 'widgets/page_history_sheet.dart';
import 'widgets/sidebar.dart';

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
  final List<String> _aiAttachmentPaths = [];
  bool _aiChatBusy = false;
  AiTokenUsage? _lastChatTokenUsage;
  double _aiPanelWidth = 360;
  bool _aiPanelCollapsed = false;
  final Set<String> _expandedThoughtMessageKeys = <String>{};

  VaultSession get _s => widget.session;
  AiChatThreadData get _activeChat => _s.activeAiChat;

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
        first.toLowerCase().contains('**agent decision:**');
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
    _s.addListener(_onSession);
    _syncTitleFromSession();
  }

  @override
  void dispose() {
    _s.removeListener(_onSession);
    _titleController.dispose();
    _chatInputController.dispose();
    _chatInputFocusNode.dispose();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    _syncTitleFromSession();
    setState(() {});
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

  bool _shouldHandleShortcut() {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final focusedWidget = focusedContext?.widget;
    return focusedWidget is! EditableText;
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
    if (mounted) setState(() {});
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
    try {
      await _s.pingAi();
    } catch (e) {
      if (mounted) {
        setState(() => _aiChatBusy = false);
        final l10n = AppLocalizations.of(context);
        final msg = e is AiServiceUnreachableException
            ? l10n.aiServiceUnreachable
            : l10n.aiErrorWithDetails(e);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.aiErrorWithDetails(e))));
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
      attachments: attachments,
      languageCode: languageCode,
    );
  }

  void _createNewChat() {
    setState(() => _lastChatTokenUsage = null);
    _s.createNewAiChat();
  }

  void _deleteActiveChat() {
    setState(() => _lastChatTokenUsage = null);
    _s.deleteActiveAiChat();
  }

  Widget _buildEditorContent({
    required BuildContext context,
    required bool compact,
    required ColorScheme scheme,
    required FolioPage? page,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 0 : FolioSpace.sm,
        0,
        compact ? 0 : FolioSpace.md,
        compact ? 0 : FolioSpace.md,
      ),
      child: Material(
        color: scheme.surface,
        elevation: compact ? 0 : 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.1),
        borderRadius: compact
            ? BorderRadius.zero
            : BorderRadius.circular(FolioRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: page == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(FolioSpace.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 56,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).noPages,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: FolioSpace.md),
                      FilledButton.icon(
                        onPressed: () => _s.addPage(parentId: null),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(AppLocalizations.of(context).createPage),
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(
                  FolioSpace.lg,
                  FolioSpace.md,
                  FolioSpace.lg,
                  FolioSpace.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        filled: false,
                        hintText: AppLocalizations.of(context).untitled,
                        isDense: true,
                        hintStyle: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      onChanged: (v) {
                        if (page.id == _s.selectedPageId) {
                          _s.renamePage(page.id, v);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: BlockEditor(
                        key: ValueKey('${page.id}-${_s.contentEpoch}'),
                        session: _s,
                      ),
                    ),
                  ],
                ),
              ),
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
            borderRadius: BorderRadius.circular(4),
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
                          _s.selectedPage?.title ?? l10n.aiNoPageSelected,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
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
                            setState(() => _lastChatTokenUsage = null);
                            _s.selectAiChat(i);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
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
              child: _activeChat.messages.isEmpty
                  ? Center(
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
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      itemCount: _activeChat.messages.length,
                      itemBuilder: (context, i) {
                        final m = _activeChat.messages[i];
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
                                  onDeleted: () => setState(
                                    () => _aiAttachmentPaths.remove(p),
                                  ),
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
    final compact = width < 1000;
    final isAiPanelVisible =
        !compact &&
        widget.appSettings.isAiRuntimeEnabled &&
        _s.aiEnabled &&
        !_aiPanelCollapsed;
    final fabRightOffset = isAiPanelVisible ? _aiPanelWidth + 18 : 0.0;
    final sidePanel = Material(
      color: scheme.surfaceContainerLow,
      child: Sidebar(session: _s),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          if (_shouldHandleShortcut()) widget.onOpenSearch();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          if (_shouldHandleShortcut()) widget.onOpenSearch();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          if (_shouldHandleShortcut()) _s.addPage(parentId: null);
        },
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          if (_shouldHandleShortcut()) _openSettings();
        },
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
          if (_shouldHandleShortcut()) _s.lock();
        },
        const SingleActivator(LogicalKeyboardKey.bracketRight, alt: true): () {
          if (_shouldHandleShortcut()) _selectAdjacentPage(1);
        },
        const SingleActivator(LogicalKeyboardKey.bracketLeft, alt: true): () {
          if (_shouldHandleShortcut()) _selectAdjacentPage(-1);
        },
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
          if (_shouldHandleShortcut()) _s.clearSelectedPage();
        },
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: scheme.surfaceContainerLow,
        drawer: compact
            ? Drawer(
                width: width.clamp(260, 340),
                child: SafeArea(child: sidePanel),
              )
            : null,
        appBar: AppBar(
          title: Text(l10n.appTitle),
          leading: compact
              ? IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).openAppDrawerTooltip,
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                )
              : null,
          actions: [
            if (widget.appSettings.isAiRuntimeEnabled && _s.aiEnabled)
              IconButton(
                tooltip: _aiPanelCollapsed
                    ? l10n.aiShowPanel
                    : l10n.aiHidePanel,
                icon: Icon(
                  _aiPanelCollapsed
                      ? Icons.chat_bubble_outline_rounded
                      : Icons.close_fullscreen_rounded,
                ),
                onPressed: () =>
                    setState(() => _aiPanelCollapsed = !_aiPanelCollapsed),
              ),
            if (_s.hasPendingDiskSave || _s.isPersistingToDisk)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: FolioSpace.xs),
                child: Center(
                  child: Tooltip(
                    message: _s.isPersistingToDisk
                        ? l10n.savingVaultTooltip
                        : l10n.autosaveSoonTooltip,
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
                            size: 22,
                            color: scheme.primary.withValues(alpha: 0.85),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _s.isPersistingToDisk
                              ? l10n.saveInProgress
                              : l10n.savePending,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (page != null)
              IconButton(
                tooltip: l10n.pageHistory,
                icon: const Icon(Icons.history_rounded),
                onPressed: _openPageHistoryScreen,
              ),
            if (page != null)
              IconButton(
                tooltip: l10n.closeCurrentPage,
                icon: const Icon(Icons.tab_unselected_rounded),
                onPressed: _s.clearSelectedPage,
              ),
            IconButton(
              tooltip: l10n.search,
              icon: const Icon(Icons.search_rounded),
              onPressed: widget.onOpenSearch,
            ),
            IconButton(
              tooltip: l10n.settings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
            IconButton(
              tooltip: l10n.lockNow,
              icon: const Icon(Icons.lock_outline),
              onPressed: () => _s.lock(),
            ),
          ],
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) SizedBox(width: 320, child: sidePanel),
            Expanded(
              child: _buildEditorContent(
                context: context,
                compact: compact,
                scheme: scheme,
                page: page,
              ),
            ),
            if (isAiPanelVisible)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) {
                    final screenW = MediaQuery.sizeOf(context).width;
                    final maxW = (screenW * 0.55).clamp(320.0, 700.0);
                    setState(() {
                      _aiPanelWidth = (_aiPanelWidth - d.delta.dx).clamp(
                        280.0,
                        maxW,
                      );
                    });
                  },
                  child: Container(
                    width: 6,
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
            if (isAiPanelVisible)
              SizedBox(width: _aiPanelWidth, child: _buildAiPanel(context)),
          ],
        ),
        floatingActionButton: page != null
            ? Padding(
                padding: EdgeInsets.only(right: fabRightOffset),
                child: FloatingActionButton(
                  onPressed: () async {
                    final type = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const BlockTypePickerSheet(
                        catalog: blockTypeCatalog,
                      ),
                    );
                    if (type != null && mounted) {
                      _s.appendBlock(
                        pageId: page.id,
                        block: FolioBlock(
                          id: '${page.id}_${const Uuid().v4()}',
                          type: type,
                          text: '',
                          checked: type == 'todo' ? false : null,
                          codeLanguage: type == 'code' ? 'dart' : null,
                        ),
                      );
                    }
                  },
                  child: const Icon(Icons.add_rounded),
                ),
              )
            : null,
      ),
    );
  }
}
