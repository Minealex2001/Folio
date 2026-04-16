import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_settings.dart';
import '../../../app/folio_in_app_shortcuts.dart';
import '../../../app/ui_tokens.dart';
import '../../../app/widgets/folio_cloud_ai_ink_dialog.dart';
import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_feedback.dart';
import '../../../models/folio_page.dart';
import '../../../models/block.dart';
import '../../../models/folio_columns_data.dart';
import '../../../models/folio_template_button_data.dart';
import '../../../models/folio_toggle_data.dart';
import '../../../models/folio_kanban_data.dart';
import '../../../services/ai/ai_types.dart';
import '../../../services/ai/folio_cloud_ai_service.dart';
import '../../../services/cloud_account/cloud_account_controller.dart';
import '../../../services/collab/collab_session_controller.dart';
import '../../../services/folio_cloud/folio_cloud_checkout.dart';
import '../../../services/folio_cloud/folio_cloud_purchase_channel_dialog.dart';
import '../../../services/folio_cloud/folio_microsoft_store_channel.dart';
import '../../../services/folio_cloud/folio_microsoft_store_sync.dart';
import '../../../services/folio_cloud/folio_cloud_ai_pricing.dart';
import '../../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../../services/folio_cloud/folio_cloud_publish.dart';
import '../../../services/folio_cloud/folio_page_html_export.dart';
import '../../../services/folio_cloud/folio_page_pdf_export.dart';
import '../../../services/device_sync/device_sync_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../data/vault_paths.dart';
import '../../../services/integrations/integrations_markdown_codec.dart';
import '../../../session/vault_session.dart';
import '../../settings/folio_cloud_subscription_pitch_page.dart';
import '../../settings/settings_page.dart' show SettingsPage;
import 'ai_typing_indicator.dart';
import '../editor/ai_typewriter_message.dart';
import '../editor/block_editor.dart';
import '../editor/block_editor_support_widgets.dart';
import '../history/page_history_sheet.dart';
import '../history/mermaid_markdown_builder.dart';
import 'sidebar.dart';
import '../history/page_outline_panel.dart';
import '../collab/collaboration_sheet.dart';
import 'workspace_editor_surface.dart';
import 'workspace_shell.dart';
import '../tasks/task_quick_add_dialog.dart';
import '../drive/drive_page.dart';
import '../kanban/kanban_board_page.dart';

part 'workspace_page_ai_chat.dart';
part 'workspace_page_ai_context.dart';
part 'workspace_page_ai_threads.dart';
part 'workspace_page_collab.dart';
part 'workspace_page_page_tools.dart';
part 'workspace_page_ai_attachments.dart';
part 'workspace_page_ai_panel.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    super.key,
    required this.session,
    required this.appSettings,
    required this.deviceSyncController,
    required this.cloudAccountController,
    required this.folioCloudEntitlements,
    required this.onOpenSearch,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final DeviceSyncController deviceSyncController;
  final CloudAccountController cloudAccountController;
  final FolioCloudEntitlementsController folioCloudEntitlements;
  final VoidCallback onOpenSearch;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

enum _AiContextItemKind { currentPage, page, file, addFile, meetingNote }

enum _AiContextMenuView { root, pages }

enum _MeetingNoteAiPayload { transcript, audio, both }

class _AiContextItem {
  const _AiContextItem({
    required this.kind,
    required this.id,
    required this.label,
    this.path,
  });

  final _AiContextItemKind kind;
  final String id;
  final String label;
  final String? path;
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final TextEditingController _titleController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _chatInputController = TextEditingController();
  final FocusNode _chatInputFocusNode = FocusNode();
  final LayerLink _aiComposerLayerLink = LayerLink();
  OverlayEntry? _aiContextMenuOverlay;
  String _aiContextQuery = '';
  bool _aiContextMenuPinned = false;
  _AiContextMenuView _aiContextMenuView = _AiContextMenuView.root;
  List<String> _aiAttachmentPaths = [];
  final Map<String, _MeetingNoteAiPayload> _aiMeetingPayloads = {};
  final Map<String, String> _aiMeetingTranscripts = {};
  late String _attachmentsBoundChatId;
  bool _aiChatBusy = false;
  AiTokenUsage? _lastChatTokenUsage;
  String _aiInkEstimateOperationKind = 'chat_turn';
  double _aiPanelWidth = 360;
  bool _aiPanelCollapsed = false;
  double _collabPanelWidth = 360;
  double _collabPanelHeight = 480;
  bool _collabPanelCollapsed = true;
  bool _collabSheetOpen = false;
  int _collabUnreadCount = 0;
  String? _lastCollabObservedMessageId;
  String? _lastCollabObservedRoomId;
  bool _showQuillWorkspaceTour = false;

  /// Al abrir el editor clásico en una página con Kanban, se guarda su id aquí.
  String? _kanbanClassicEditPageId;
  String? _lastSessionPageIdForKanban;

  /// Al abrir el editor clásico en una página con Drive, se guarda su id aquí.
  String? _driveClassicEditPageId;
  final Set<String> _expandedThoughtMessageKeys = <String>{};
  final ScrollController _aiChatScrollController = ScrollController();

  /// Scroll del listado de mensajes cuando el chat va en hoja móvil (DraggableScrollableSheet).
  ScrollController? _mobileSheetChatScroll;
  String? _lastAiChatIdForScroll;
  int _lastAiChatMessageCount = -1;
  final Set<String> _aiTypewriterActiveMessageKeys = <String>{};
  final Map<int, String?> _messageFeedback =
      {}; // Track feedback for each message
  Timer? _draftSaveTimer;
  String _chatDraft = ''; // Auto-save draft
  int _aiContextMenuSelectedIndex = 0; // Keyboard navigation
  bool _aiContextMenuUsingKeyboard = false; // Track keyboard vs mouse
  bool _mobileEditMode = false;
  String? _lastPageIdForMobileMode;
  bool _sidebarPeek = false;
  double _aiPanelHeight = 520;
  bool _folioCloudCheckoutBusy = false;
  Map<String, int> _cloudInkCostByOperation = Map<String, int>.from(
    kFolioCloudInkCostFallback,
  );
  bool _cloudInkPricingFromServer = false;

  final Map<String, GlobalKey<BlockEditorState>> _blockEditorKeysByPage =
      <String, GlobalKey<BlockEditorState>>{};

  GlobalKey<BlockEditorState> _blockEditorKeyForPage(String pageId) {
    return _blockEditorKeysByPage.putIfAbsent(
      pageId,
      () => GlobalKey<BlockEditorState>(debugLabel: 'block_editor_$pageId'),
    );
  }

  late final CollabSessionController _collab;

  VaultSession get _s => widget.session;
  AiChatThreadData get _activeChat => _s.activeAiChat;

  void _snack(String message, {bool error = false}) {
    if (!mounted || message.trim().isEmpty) return;
    showFolioSnack(context, message, error: error);
  }

  void _setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _applyAiChatPanelCollapsed(bool collapsed) {
    if (!mounted) return;
    if (_aiPanelCollapsed != collapsed) {
      setState(() => _aiPanelCollapsed = collapsed);
    }
    unawaited(widget.appSettings.setAiChatPanelCollapsed(collapsed));
  }

  String _t(String es, String en) {
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    return lang.startsWith('es') ? es : en;
  }

  int _inkCostForOperationKind(String kind) {
    final fallbackDefault = kFolioCloudInkCostFallback['default'] ?? 3;
    return _cloudInkCostByOperation[kind] ??
        _cloudInkCostByOperation['default'] ??
        fallbackDefault;
  }

  Future<void> _refreshCloudInkPricing({bool force = false}) async {
    final snap = await FolioCloudAiPricingService.getPricing(
      forceRefresh: force,
    );
    if (!mounted) return;
    setState(() {
      _cloudInkCostByOperation = Map<String, int>.from(snap.costByOperation);
      _cloudInkPricingFromServer = snap.fromServer;
    });
  }

  String _estimateInkOperationKindForChat({
    required String text,
    required bool hasScopePage,
  }) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return 'chat_turn';

    bool hasAny(List<String> needles) =>
        needles.any((n) => t.contains(n.toLowerCase()));

    // Crear contenido nuevo suele ser más caro.
    if (hasAny([
      'crear',
      'crea ',
      'crea una',
      'crea un',
      'nueva página',
      'nuevo documento',
      'genera una página',
      'generate a page',
      'create a page',
    ])) {
      return 'generate_page';
    }

    if (hasAny([
      'insertar',
      'inserta',
      'añade un párrafo',
      'añadir un párrafo',
      'añade',
      'añadir',
      'generate insert',
    ])) {
      return 'generate_insert';
    }

    if (hasAny(['resume', 'resumen', 'resumir', 'summarize'])) {
      return 'summarize_page';
    }

    // Si hay una página abierta y el texto sugiere edición, estimar modo de edición.
    if (hasScopePage &&
        hasAny([
          'reescribe',
          'reescribir',
          'corrige',
          'corregir',
          'mejora',
          'mejorar',
          'cambia',
          'cambiar',
          'actualiza',
          'actualizar',
          'editar',
          'edit ',
          'rewrite',
        ])) {
      return 'edit_page_panel';
    }

    return 'chat_turn';
  }

  void _updateInkEstimateFromComposer() {
    if (!mounted) return;
    final isCloudProvider =
        widget.appSettings.aiProvider == AiProvider.quillCloud;
    if (!isCloudProvider) return;
    final next = _estimateInkOperationKindForChat(
      text: _chatInputController.text,
      hasScopePage: _s.selectedPageId != null,
    );
    if (next == _aiInkEstimateOperationKind) return;
    setState(() => _aiInkEstimateOperationKind = next);
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

  String _formatMessageTimestamp(BuildContext context, DateTime timestamp) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return l10n.aiMessageTimestampNow;
    }
    if (diff.inMinutes < 60) {
      return l10n.aiMessageTimestampMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return l10n.aiMessageTimestampHours(diff.inHours);
    }
    return l10n.aiMessageTimestampDays(diff.inDays);
  }

  Future<void> _copyToClipboard(String text, String feedbackMsg) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      _snack(feedbackMsg);
    }
  }

  void _updateMessageFeedback(int messageIndex, String? feedback) {
    final msgs = _activeChat.messages;
    if (messageIndex < 0 || messageIndex >= msgs.length) return;
    final old = msgs[messageIndex];
    final updated = AiChatMessage(
      role: old.role,
      content: old.content,
      timestamp: old.timestamp,
      feedback: feedback,
    );
    _s.updateMessageInActiveAiChat(messageIndex, updated);
  }

  Widget _buildAiMessageRow(
    BuildContext context,
    AiChatMessage message,
    int messageIndex,
    ThemeData theme,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    final isUser = message.role == 'user';
    final split = _splitAgentThought(message.content);
    final thought = split.thought;
    final bodyContent = split.body;
    final msgKey = '${_activeChat.id}#$messageIndex';
    final alwaysShowThought = widget.appSettings.aiAlwaysShowThought;
    final thoughtExpanded =
        alwaysShowThought || _expandedThoughtMessageKeys.contains(msgKey);
    final bubbleColor = isUser
        ? scheme.primaryContainer.withValues(alpha: 0.92)
        : scheme.surface;
    final textColor = isUser ? scheme.onPrimaryContainer : scheme.onSurface;
    final feedback = _messageFeedback[messageIndex] ?? message.feedback;
    final isHelpful = feedback == 'helpful';
    final isNotHelpful = feedback == 'not_helpful';

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Padding(
              padding: const EdgeInsets.only(left: 42, bottom: 4),
              child: Text(
                _formatMessageTimestamp(context, message.timestamp),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 12, top: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.secondaryContainer,
                        scheme.tertiaryContainer,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              Flexible(
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isUser ? 16 : 14,
                      vertical: isUser ? 12 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      border: Border.all(
                        color: isUser
                            ? scheme.primary.withValues(alpha: 0.12)
                            : scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(22).copyWith(
                        bottomRight: isUser ? const Radius.circular(8) : null,
                        topLeft: !isUser ? const Radius.circular(8) : null,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isUser && thought != null && thought.isNotEmpty)
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: alwaysShowThought
                                ? null
                                : () {
                                    setState(() {
                                      if (_expandedThoughtMessageKeys.contains(
                                        msgKey,
                                      )) {
                                        _expandedThoughtMessageKeys.remove(
                                          msgKey,
                                        );
                                      } else {
                                        _expandedThoughtMessageKeys.add(msgKey);
                                      }
                                    });
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    thoughtExpanded
                                        ? Icons.keyboard_arrow_down_rounded
                                        : Icons.keyboard_arrow_right_rounded,
                                    size: 18,
                                    color: textColor.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      l10n.aiAgentThought,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: textColor.withValues(
                                              alpha: 0.85,
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!isUser &&
                            thought != null &&
                            thought.isNotEmpty &&
                            thoughtExpanded) ...[
                          const SizedBox(height: 10),
                          _buildMarkdownMessage(
                            context: context,
                            content: thought,
                            isUser: isUser,
                            textColor: textColor,
                          ),
                          const SizedBox(height: 10),
                          Divider(
                            height: 1,
                            color: textColor.withValues(alpha: 0.14),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Builder(
                          builder: (ctx) {
                            final target = bodyContent.isEmpty
                                ? message.content
                                : bodyContent;
                            final shouldAnimate =
                                !isUser &&
                                _aiTypewriterActiveMessageKeys.contains(msgKey);
                            if (!shouldAnimate) {
                              return _buildMarkdownMessage(
                                context: ctx,
                                content: target,
                                isUser: isUser,
                                textColor: textColor,
                              );
                            }
                            final baseStyle = Theme.of(ctx).textTheme.bodyMedium
                                ?.copyWith(color: textColor, height: 1.35);
                            return FolioAiTypewriterMessage(
                              fullText: _normalizeHtmlForChat(target),
                              style:
                                  baseStyle ??
                                  TextStyle(color: textColor, height: 1.35),
                              onCompleted: () {
                                if (!mounted) return;
                                setState(() {
                                  _aiTypewriterActiveMessageKeys.remove(msgKey);
                                });
                              },
                            );
                          },
                        ),
                        if (!isUser) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconButton(
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  Icons.content_copy_rounded,
                                  color: textColor.withValues(alpha: 0.7),
                                ),
                                tooltip: l10n.aiCopyMessage,
                                onPressed: () => _copyToClipboard(
                                  bodyContent.isEmpty
                                      ? message.content
                                      : bodyContent,
                                  l10n.aiCopiedToClipboard,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                style: ButtonStyle(
                                  iconColor: WidgetStateProperty.resolveWith(
                                    (_) => isHelpful
                                        ? scheme.primary
                                        : textColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                icon: const Icon(Icons.thumb_up_rounded),
                                tooltip: l10n.aiHelpful,
                                onPressed: () {
                                  final newFeedback = isHelpful
                                      ? null
                                      : 'helpful';
                                  setState(
                                    () => _messageFeedback[messageIndex] =
                                        newFeedback,
                                  );
                                  _updateMessageFeedback(
                                    messageIndex,
                                    newFeedback,
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                style: ButtonStyle(
                                  iconColor: WidgetStateProperty.resolveWith(
                                    (_) => isNotHelpful
                                        ? scheme.error
                                        : textColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                icon: const Icon(Icons.thumb_down_rounded),
                                tooltip: l10n.aiNotHelpful,
                                onPressed: () {
                                  final newFeedback = isNotHelpful
                                      ? null
                                      : 'not_helpful';
                                  setState(
                                    () => _messageFeedback[messageIndex] =
                                        newFeedback,
                                  );
                                  _updateMessageFeedback(
                                    messageIndex,
                                    newFeedback,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 12),
            ],
          ),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 4),
              child: Text(
                _formatMessageTimestamp(context, message.timestamp),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_AiContextItem> _buildActiveAiContextItems(AppLocalizations l10n) {
    final items = <_AiContextItem>[];
    final page = _s.selectedPage;
    if (_activeChat.includePageContext && _activeChat.contextPageIds.isEmpty) {
      items.add(
        _AiContextItem(
          kind: _AiContextItemKind.currentPage,
          id: page?.id ?? '__current_page__',
          label: page?.title.isNotEmpty == true
              ? l10n.aiContextCurrentPageChip(page!.title)
              : l10n.aiContextCurrentPageFallback,
        ),
      );
    }
    for (final pageId in _activeChat.contextPageIds) {
      final match = _s.pages.where((p) => p.id == pageId).firstOrNull;
      items.add(
        _AiContextItem(
          kind: _AiContextItemKind.page,
          id: pageId,
          label: match == null || match.title.trim().isEmpty
              ? l10n.untitledFallback
              : match.title,
        ),
      );
    }
    for (final path in _aiAttachmentPaths) {
      final isMeeting = _aiMeetingPayloads.containsKey(path);
      final label = isMeeting
          ? _meetingNoteChipLabel(l10n, path)
          : path.split(RegExp(r'[/\\]')).last;
      items.add(
        _AiContextItem(
          kind: isMeeting
              ? _AiContextItemKind.meetingNote
              : _AiContextItemKind.file,
          id: path,
          label: label,
          path: path,
        ),
      );
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    _aiPanelWidth = widget.appSettings.aiChatPanelWidth;
    _aiPanelCollapsed = widget.appSettings.aiChatPanelCollapsed;
    _aiPanelHeight = widget.appSettings.aiChatPanelHeight;
    _collab = CollabSessionController(
      vaultSession: widget.session,
      folioCloudEntitlements: widget.folioCloudEntitlements,
    );
    _collab.addListener(_onCollabController);
    _titleController = TextEditingController();
    _attachmentsBoundChatId = _s.activeAiChat.id;
    _aiAttachmentPaths = List<String>.from(_s.activeAiChat.attachmentPaths);
    _s.addListener(_onSession);
    widget.appSettings.addListener(_onAppSettings);
    HardwareKeyboard.instance.addHandler(_onHardwareKeyEvent);
    _chatInputController.addListener(_updateAiContextMenu);
    _chatInputFocusNode.addListener(_updateAiContextMenu);
    widget.folioCloudEntitlements.addListener(_onFolioCloudEntitlements);
    unawaited(_refreshCloudInkPricing());
    _syncTitleFromSession();
    _lastSessionPageIdForKanban = _s.selectedPageId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowQuillWorkspaceTour();
      _syncCollabForSelectedPage();
    });
  }

  @override
  void dispose() {
    _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
    _hideAiContextMenu();
    _draftSaveTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onHardwareKeyEvent);
    widget.appSettings.removeListener(_onAppSettings);
    widget.folioCloudEntitlements.removeListener(_onFolioCloudEntitlements);
    _collab.removeListener(_onCollabController);
    _collab.dispose();
    _s.removeListener(_onSession);
    _chatInputController.removeListener(_updateAiContextMenu);
    _chatInputFocusNode.removeListener(_updateAiContextMenu);
    _titleController.dispose();
    _chatInputController.dispose();
    _chatInputFocusNode.dispose();
    _aiChatScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folioCloudEntitlements != widget.folioCloudEntitlements) {
      oldWidget.folioCloudEntitlements.removeListener(
        _onFolioCloudEntitlements,
      );
      widget.folioCloudEntitlements.addListener(_onFolioCloudEntitlements);
    }
  }

  void _onFolioCloudEntitlements() {
    if (!_cloudInkPricingFromServer &&
        widget.folioCloudEntitlements.snapshot.canUseCloudAi) {
      unawaited(_refreshCloudInkPricing(force: true));
    }
    _syncCollabForSelectedPage();
    if (mounted) setState(() {});
  }

  void _scheduleAiChatScrollToBottom() {
    final controller = _mobileSheetChatScroll ?? _aiChatScrollController;
    void scrollNow() {
      if (!mounted || !controller.hasClients) return;
      final pos = controller.position;
      controller.animateTo(
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
    final currentPageId = _s.selectedPageId;
    if (currentPageId != _lastSessionPageIdForKanban) {
      _lastSessionPageIdForKanban = currentPageId;
      _kanbanClassicEditPageId = null;
      _driveClassicEditPageId = null;
    }
    if (currentPageId != _lastPageIdForMobileMode) {
      _lastPageIdForMobileMode = currentPageId;
      final media = MediaQuery.maybeOf(context);
      final size = media?.size;
      final isVerticalMobile =
          size != null &&
          FolioAdaptive.isAndroidPhoneWidth(size.width) &&
          size.height > size.width;
      if (isVerticalMobile && _mobileEditMode) {
        _mobileEditMode = false;
      }
    }
    if (_s.activeAiChat.id != _attachmentsBoundChatId) {
      _attachmentsBoundChatId = _s.activeAiChat.id;
      _aiAttachmentPaths = List<String>.from(_s.activeAiChat.attachmentPaths);
      // Los metadatos de meeting son in-memory; al cambiar de chat, limpiar huérfanos.
      _aiMeetingPayloads.removeWhere((k, _) => !_aiAttachmentPaths.contains(k));
      _aiMeetingTranscripts.removeWhere(
        (k, _) => !_aiAttachmentPaths.contains(k),
      );
    }
    final chat = _s.activeAiChat;
    final previousThreadId = _lastAiChatIdForScroll;
    final previousCount = _lastAiChatMessageCount;
    final threadChanged = chat.id != previousThreadId;
    final countChanged = chat.messages.length != previousCount;
    _lastAiChatIdForScroll = chat.id;
    _lastAiChatMessageCount = chat.messages.length;
    if (threadChanged) {
      _aiTypewriterActiveMessageKeys.clear();
    }
    _syncTitleFromSession();
    _syncCollabForSelectedPage();
    setState(() {});
    _updateAiContextMenu();
    if (countChanged || threadChanged) {
      _scheduleAiChatScrollToBottom();
    }
    // Disparar animación SOLO para mensajes nuevos del hilo actual (evita animar historial al cargar/cambiar hilo).
    if (!threadChanged &&
        previousCount >= 0 &&
        chat.messages.length == previousCount + 1 &&
        chat.messages.isNotEmpty) {
      final lastIndex = chat.messages.length - 1;
      final last = chat.messages[lastIndex];
      if (last.role == 'assistant') {
        final key = '${chat.id}#$lastIndex';
        _aiTypewriterActiveMessageKeys.add(key);
      }
    }
  }

  void _onAppSettings() {
    _maybeShowQuillWorkspaceTour();
    if (!mounted) return;
    setState(() {
      _aiPanelWidth = widget.appSettings.aiChatPanelWidth;
      _aiPanelCollapsed = widget.appSettings.aiChatPanelCollapsed;
      _aiPanelHeight = widget.appSettings.aiChatPanelHeight;
    });
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
        activator: a.inAppShortcut(FolioInAppShortcut.quickAddTask),
        action: () {
          if (_shouldHandleShortcut(FolioInAppShortcut.quickAddTask)) {
            unawaited(_showQuickAddTask());
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
            unawaited(_s.lock());
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
    final w = MediaQuery.sizeOf(context).width;
    final androidMobile = FolioAdaptive.shouldUseMobileWorkspace(w);
    final compact = w < FolioDesktop.compactBreakpoint || androidMobile;
    final aiOn = widget.appSettings.isAiRuntimeEnabled && _s.aiEnabled;
    if (aiOn && !compact) {
      _applyAiChatPanelCollapsed(false);
    }
    setState(() {
      _showQuillWorkspaceTour = true;
    });
    if (aiOn && compact) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openMobileAiChatSheet());
      });
    }
  }

  Future<void> _dismissQuillWorkspaceTour() async {
    if (!_showQuillWorkspaceTour) return;
    setState(() => _showQuillWorkspaceTour = false);
    await widget.appSettings.setHasSeenQuillWorkspaceTour(true);
  }

  void _useQuillTourPrompt(String prompt) {
    final w = MediaQuery.sizeOf(context).width;
    final androidMobile = FolioAdaptive.shouldUseMobileWorkspace(w);
    final compact = w < FolioDesktop.compactBreakpoint || androidMobile;
    final aiOn = widget.appSettings.isAiRuntimeEnabled && _s.aiEnabled;
    if (aiOn && !compact) {
      _applyAiChatPanelCollapsed(false);
    }
    setState(() {
      _chatInputController.value = TextEditingValue(
        text: prompt,
        selection: TextSelection.collapsed(offset: prompt.length),
      );
    });
    if (aiOn && compact) {
      unawaited(_openMobileAiChatSheet());
    }
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
        builder: (ctx) => SettingsPage(
          session: _s,
          appSettings: widget.appSettings,
          deviceSyncController: widget.deviceSyncController,
          cloudAccountController: widget.cloudAccountController,
          folioCloudEntitlements: widget.folioCloudEntitlements,
        ),
      ),
    );
  }

  void _openFolioCloudSubscriptionPitch() {
    if (_folioCloudCheckoutBusy) return;
    final l10n = AppLocalizations.of(context);
    final signedIn = widget.cloudAccountController.isSignedIn;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => FolioCloudSubscriptionPitchPage(
          busy: _folioCloudCheckoutBusy,
          primaryCtaLabel: signedIn
              ? l10n.folioCloudSubscribeMonthly
              : l10n.folioCloudPitchCtaNeedAccount,
          primaryIcon: signedIn
              ? Icons.subscriptions_outlined
              : Icons.person_add_outlined,
          onPrimaryCta: () {
            Navigator.of(ctx).pop();
            if (!mounted) return;
            if (signedIn) {
              unawaited(_openFolioCloudMonthlyCheckout());
            } else {
              _openSettings();
              _snack(l10n.folioCloudPitchOpenSettingsToSignIn);
            }
          },
        ),
      ),
    );
  }

  Future<void> _openFolioCloudMonthlyCheckout() async {
    if (_folioCloudCheckoutBusy) return;
    var channel = FolioCloudPurchaseChannel.stripeInBrowser;
    if (FolioMicrosoftStoreChannel.isRuntimeSupported) {
      final pick = await showFolioCloudPurchaseChannelDialog(
        context,
        checkoutKind: FolioCheckoutKind.folioCloudMonthly,
      );
      if (!mounted) return;
      if (pick == null) return;
      channel = pick;
    }
    setState(() => _folioCloudCheckoutBusy = true);
    try {
      final l10n = AppLocalizations.of(context);
      if (channel == FolioCloudPurchaseChannel.microsoftStore) {
        try {
          await purchaseMicrosoftStoreMonthlyIfConfigured();
          if (mounted) {
            _snack(l10n.folioCloudMicrosoftStoreAppliedSnack);
          }
        } catch (e) {
          _snack('$e', error: true);
        }
        return;
      }
      final uri = await createFolioCheckoutUri(
        FolioCheckoutKind.folioCloudMonthly,
      );
      if (uri == null) {
        _snack(
          _t(
            'Pago no disponible (configura Stripe en el servidor).',
            'Checkout unavailable (configure Stripe on server).',
          ),
          error: true,
        );
        return;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _snack(
          _t('No se pudo abrir el enlace.', 'Could not open the link.'),
          error: true,
        );
      } else {
        widget.folioCloudEntitlements.scheduleStripeSyncOnNextResume();
      }
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _folioCloudCheckoutBusy = false);
    }
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
      case FolioInAppShortcut.quickAddTask:
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

  void _openPageHistoryScreen([BuildContext? anchorContext]) {
    final page = _s.selectedPage;
    if (page == null) return;
    openPageHistoryScreen(
      context: anchorContext ?? context,
      session: _s,
      page: page,
    );
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
        builder: (_) => const BlockTypePickerSheet(),
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
          child: const BlockTypePickerSheet(),
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
      text = FolioTemplateButtonData.localizedDefault(
        AppLocalizations.of(context),
      ).encode();
    } else if (type == 'column_list') {
      text = FolioColumnsData.empty().encode();
    } else if (type == 'equation') {
      text = r'E = mc^2';
      codeLanguage = 'plaintext';
    } else if (type == 'kanban') {
      text = FolioKanbanData.defaults().encode();
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

  Future<void> _addBlockToCurrentPageFromMenu(
    BuildContext anchorContext,
  ) async {
    final page = _s.selectedPage;
    if (page == null) return;
    final type = await showBlockTypePickerMenu(anchorContext: anchorContext);
    if (type == null || !mounted) return;
    _appendBlockToPage(page, type);
  }

  void _forceSyncNow() {
    try {
      widget.deviceSyncController.refreshSettingsSnapshot();
      widget.deviceSyncController.onLocalSnapshotPersisted();
      if (mounted) {
        _snack('Sincronización forzada iniciada.');
      }
    } catch (e) {
      if (mounted) {
        _snack('No se pudo forzar la sincronización: $e', error: true);
      }
    }
  }

  Future<void> _showQuickAddTask() async {
    final kanbanPages = _s.pages
        .where((p) => p.blocks.any((b) => b.type == 'kanban'))
        .toList();
    if (kanbanPages.isEmpty) return;

    if (kanbanPages.length == 1) {
      await showTaskQuickAddDialog(
        context: context,
        session: _s,
        appSettings: widget.appSettings,
        targetPageId: kanbanPages.single.id,
      );
    } else {
      final l10n = AppLocalizations.of(context);
      final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final scheme = Theme.of(sheetContext).colorScheme;
          final theme = Theme.of(sheetContext);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(FolioSpace.md),
              child: Material(
                color: scheme.surface,
                elevation: 6,
                borderRadius: BorderRadius.circular(FolioRadius.lg),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          FolioSpace.md,
                          FolioSpace.md,
                          FolioSpace.md,
                          FolioSpace.sm,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.view_kanban_rounded),
                            const SizedBox(width: FolioSpace.sm),
                            Expanded(
                              child: Text(
                                l10n.sidebarQuickAddTask,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.cancel,
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop<String>(null),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: kanbanPages.length,
                          separatorBuilder: (context, _) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final p = kanbanPages[i];
                            final title = p.title.trim().isEmpty
                                ? l10n.untitled
                                : p.title.trim();
                            return ListTile(
                              leading: const Icon(Icons.description_outlined),
                              title: Text(title),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop<String>(p.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      if (selected != null && mounted) {
        await showTaskQuickAddDialog(
          context: context,
          session: _s,
          appSettings: widget.appSettings,
          targetPageId: selected,
        );
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final page = _s.selectedPage;

    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final androidMobileWorkspace = FolioAdaptive.shouldUseMobileWorkspace(
      width,
    );
    final androidPhoneLayout = FolioAdaptive.isAndroidPhoneWidth(width);
    final verticalMobileWorkspace = androidPhoneLayout && height > width;
    final editorReadOnlyMode = verticalMobileWorkspace && !_mobileEditMode;
    final compact =
        width < FolioDesktop.compactBreakpoint || androidMobileWorkspace;
    final aiSessionActive =
        widget.appSettings.isAiRuntimeEnabled && _s.aiEnabled;
    final useDesktopAiDock = !compact && aiSessionActive;
    final useMobileAiDock = compact && aiSessionActive;
    final cloudSignedIn =
        Firebase.apps.isNotEmpty && widget.cloudAccountController.isSignedIn;
    final hasCollabRoom = _isValidCollabRoomId(page?.collabRoomId);
    final useDesktopCollabDock =
        !compact && page != null && cloudSignedIn && hasCollabRoom;
    final useMobileCollabFab =
        compact && page != null && cloudSignedIn && hasCollabRoom;
    final effectiveSidebarW = compact
        ? 0.0
        : (widget.appSettings.workspaceSidebarCollapsed
              ? (_sidebarPeek ? widget.appSettings.workspaceSidebarWidth : 0.0)
              : widget.appSettings.workspaceSidebarWidth);
    final hasAnyKanbanPage = _s.pages.any(
      (p) => p.blocks.any((b) => b.type == 'kanban'),
    );
    final sidePanel = Material(
      color: scheme.surfaceContainerLow,
      child: MouseRegion(
        onExit: (_) {
          if (widget.appSettings.workspaceSidebarCollapsed && _sidebarPeek) {
            setState(() => _sidebarPeek = false);
          }
        },
        child: Sidebar(
          session: _s,
          appSettings: widget.appSettings,
          cloudAccountController: widget.cloudAccountController,
          onSearch: widget.onOpenSearch,
          onForceSync: _forceSyncNow,
          onOpenSettings: _openSettings,
          onLock: () => unawaited(_s.lock()),
          onQuickAddTask: hasAnyKanbanPage ? _showQuickAddTask : null,
        ),
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
      a.inAppShortcut(FolioInAppShortcut.quickAddTask): () {
        if (_shouldHandleShortcut(FolioInAppShortcut.quickAddTask)) {
          unawaited(_showQuickAddTask());
        }
      },
      a.inAppShortcut(FolioInAppShortcut.settings): () {
        if (_shouldHandleShortcut(FolioInAppShortcut.settings)) {
          _openSettings();
        }
      },
      a.inAppShortcut(FolioInAppShortcut.lock): () {
        if (_shouldHandleShortcut(FolioInAppShortcut.lock)) {
          unawaited(_s.lock());
        }
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
        final entries = <_WorkspaceActionEntry>[
          if (!compact)
            _WorkspaceActionEntry(
              id: 'toggle_sidebar',
              label: widget.appSettings.workspaceSidebarCollapsed
                  ? l10n.showSidebar
                  : l10n.hideSidebar,
              icon: widget.appSettings.workspaceSidebarCollapsed
                  ? Icons.menu_open_rounded
                  : Icons.view_sidebar_rounded,
              onPressed: () async {
                await widget.appSettings.setWorkspaceSidebarCollapsed(
                  !widget.appSettings.workspaceSidebarCollapsed,
                );
                if (mounted) setState(() => _sidebarPeek = false);
              },
              forcePrimary: true,
            ),
          if (!compact && page != null)
            _WorkspaceActionEntry(
              id: 'toggle_page_outline',
              label: widget.appSettings.workspacePageOutlineVisible
                  ? l10n.hidePageOutline
                  : l10n.showPageOutline,
              icon: widget.appSettings.workspacePageOutlineVisible
                  ? Icons.view_list_rounded
                  : Icons.view_list_outlined,
              onPressed: () async {
                await widget.appSettings.setWorkspacePageOutlineVisible(
                  !widget.appSettings.workspacePageOutlineVisible,
                );
                if (mounted) setState(() {});
              },
              forcePrimary: true,
            ),
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
            label: l10n.importPage,
            icon: Icons.file_upload_outlined,
            onPressed: _importDocumentFile,
            forcePrimary: true,
          ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'export_md',
              label: l10n.exportPage,
              icon: Icons.file_download_outlined,
              onPressed: _exportCurrentPage,
            ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'publish_web',
              label: AppLocalizations.of(context).publishWebMenuLabel,
              icon: Icons.public_rounded,
              onPressed: _publishCurrentPageToWeb,
            ),
          if (page != null && cloudSignedIn && !hasCollabRoom)
            _WorkspaceActionEntry(
              id: 'collab_live',
              label: compact || _collabPanelCollapsed
                  ? l10n.collabMenuAction
                  : l10n.collabHidePanel,
              icon: !compact && !_collabPanelCollapsed
                  ? Icons.unfold_less_rounded
                  : Icons.groups_2_outlined,
              onPressed: () => _toggleCollaborationPanel(compact: compact),
            ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'save_as_template',
              label: l10n.saveAsTemplate,
              icon: Icons.bookmark_add_outlined,
              onPressed: _saveCurrentPageAsTemplate,
              forceOverflow: true,
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
              icon: Icons.close_rounded,
              onPressed: _s.clearSelectedPage,
            ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'undo_page_edit',
              label: l10n.workspaceUndoTooltip,
              icon: Icons.undo_rounded,
              onPressed: () => _s.undoPageEdits(),
              enabled: _s.canUndoSelectedPage,
              forceOverflow: true,
            ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'redo_page_edit',
              label: l10n.workspaceRedoTooltip,
              icon: Icons.redo_rounded,
              onPressed: () => _s.redoPageEdits(),
              enabled: _s.canRedoSelectedPage,
              forceOverflow: true,
            ),
        ];

        final useOverflow = compact || androidMobileWorkspace || width < 1420;
        final primaryBudget = androidPhoneLayout
            ? 1
            : (androidMobileWorkspace
                  ? 2
                  : (width >= 1660 ? 7 : (width >= 1420 ? 5 : 3)));
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
          ...primary.map((action) {
            if (action.id == 'add_block') {
              return Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: action.label,
                  icon: Icon(action.icon),
                  onPressed: action.enabled
                      ? () => _addBlockToCurrentPageFromMenu(buttonContext)
                      : null,
                ),
              );
            }
            if (action.id == 'export_md') {
              return Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: action.label,
                  icon: Icon(action.icon),
                  onPressed: action.enabled
                      ? () => _exportCurrentPage(buttonContext)
                      : null,
                ),
              );
            }
            if (action.id == 'publish_web') {
              return Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: action.label,
                  icon: Icon(action.icon),
                  onPressed: action.enabled
                      ? () => _publishCurrentPageToWeb(buttonContext)
                      : null,
                ),
              );
            }
            if (action.id == 'history') {
              return Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: action.label,
                  icon: Icon(action.icon),
                  onPressed: action.enabled
                      ? () => _openPageHistoryScreen(buttonContext)
                      : null,
                ),
              );
            }
            return IconButton(
              tooltip: action.label,
              icon: Icon(action.icon),
              onPressed: action.enabled ? action.onPressed : null,
            );
          }),
          if (overflow.isNotEmpty)
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: l10n.workspaceMoreActionsTooltip,
                icon: const Icon(Icons.more_horiz_rounded),
                onPressed: () async {
                  final chosen = await _showWorkspaceActionsMenu(
                    anchorContext: buttonContext,
                    actions: overflow,
                  );
                  if (chosen == null) return;
                  chosen.onPressed();
                },
              ),
            ),
        ];

        if (_s.hasPendingDiskSave || _s.isPersistingToDisk) {
          widgets.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(end: FolioSpace.xs),
              child: Center(
                child: Semantics(
                  label: _s.isPersistingToDisk
                      ? l10n.savingVaultTooltip
                      : l10n.autosaveSoonTooltip,
                  liveRegion: true,
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
            ),
          );
        }
        return widgets;
      }(),
    ];
    final activeBlockEditorKey = page == null
        ? null
        : _blockEditorKeyForPage(page.id);

    bool pageHasKanban(FolioPage p) => p.blocks.any((b) => b.type == 'kanban');

    bool pageHasDrive(FolioPage p) => p.blocks.any((b) => b.type == 'drive');

    final showKanbanBoard =
        page != null &&
        pageHasKanban(page) &&
        _kanbanClassicEditPageId != page.id;

    final showDrivePage =
        page != null &&
        pageHasDrive(page) &&
        _driveClassicEditPageId != page.id;

    Widget baseEditor = page == null
        ? const SizedBox.shrink()
        : KeyedSubtree(
            key: ValueKey('${page.id}-${_s.contentEpoch}'),
            child: showKanbanBoard
                ? KanbanBoardPage(
                    pageId: page.id,
                    session: _s,
                    appSettings: widget.appSettings,
                    onOpenClassicEditor: () =>
                        setState(() => _kanbanClassicEditPageId = page.id),
                  )
                : showDrivePage
                ? DrivePage(
                    pageId: page.id,
                    session: _s,
                    appSettings: widget.appSettings,
                    onOpenClassicEditor: () =>
                        setState(() => _driveClassicEditPageId = page.id),
                  )
                : BlockEditor(
                    key: activeBlockEditorKey,
                    session: _s,
                    appSettings: widget.appSettings,
                    readOnlyMode: editorReadOnlyMode,
                    folioCloudEntitlements: widget.folioCloudEntitlements,
                  ),
          );

    if (page != null &&
        pageHasDrive(page) &&
        _driveClassicEditPageId == page.id) {
      baseEditor = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.95),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FolioSpace.md,
                vertical: FolioSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.driveClassicModeBanner,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _driveClassicEditPageId = null),
                    child: Text(l10n.driveBackToDrive),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: baseEditor),
        ],
      );
    }

    if (page != null &&
        pageHasKanban(page) &&
        _kanbanClassicEditPageId == page.id) {
      baseEditor = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.95),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FolioSpace.md,
                vertical: FolioSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.kanbanClassicModeBanner,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _kanbanClassicEditPageId = null),
                    child: Text(l10n.kanbanBackToBoard),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: baseEditor),
        ],
      );
    }

    final editorSurface = WorkspaceEditorSurface(
      compact: compact,
      mobileOptimized: androidMobileWorkspace,
      readOnlyMode: editorReadOnlyMode,
      page: page,
      pagePath: _buildPagePathSegments(page),
      titleController: _titleController,
      editorMaxWidth: widget.appSettings.editorContentWidth,
      onTitleChanged: (value) {
        if (page != null && page.id == _s.selectedPageId) {
          _s.updatePageTitleLive(page.id, value);
        }
      },
      onCreatePage: () => _s.addPage(parentId: null),
      onOpenSearch: widget.onOpenSearch,
      editor: baseEditor,
    );

    final showOutlinePanel =
        !compact &&
        page != null &&
        !showKanbanBoard &&
        !showDrivePage &&
        widget.appSettings.workspacePageOutlineVisible;

    final editorContent = showOutlinePanel
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: editorSurface),
              PageOutlinePanel(
                blocks: page.blocks,
                scheme: scheme,
                blockEditorKey: activeBlockEditorKey!,
              ),
            ],
          )
        : editorSurface;
    return CallbackShortcuts(
      bindings: shortcutBindings,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: scheme.surfaceContainerLow,
        drawer: compact
            ? Drawer(
                width: androidPhoneLayout
                    ? width * 0.92
                    : width.clamp(260, 340),
                child: SafeArea(child: sidePanel),
              )
            : null,
        appBar: WorkspaceTopAppBar(
          title: androidPhoneLayout
              ? ((page?.title.trim().isNotEmpty ?? false)
                    ? page!.title.trim()
                    : l10n.appTitle)
              : l10n.appTitle,
          compact: compact,
          actions: appBarActions,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        body: WorkspaceBodyShell(
          compact: compact,
          sidePanelWidth: effectiveSidebarW,
          sidePanel: sidePanel,
          editorContent: editorContent,
          showSidebarResizeHandle:
              !compact &&
              !widget.appSettings.workspaceSidebarCollapsed &&
              effectiveSidebarW > 0,
          onResizeSidebarDelta: !compact
              ? (d) {
                  unawaited(
                    widget.appSettings.setWorkspaceSidebarWidth(
                      widget.appSettings.workspaceSidebarWidth + d,
                    ),
                  );
                }
              : null,
          sidebarLeftEdgeHover:
              !compact &&
              widget.appSettings.workspaceSidebarCollapsed &&
              widget.appSettings.workspaceSidebarAutoReveal &&
              !_sidebarPeek,
          onSidebarEdgeEnter: () {
            if (!widget.appSettings.workspaceSidebarAutoReveal ||
                !widget.appSettings.workspaceSidebarCollapsed) {
              return;
            }
            setState(() => _sidebarPeek = true);
          },
          scheme: scheme,
          betaBanner: widget.appSettings.shouldShowBetaBanner
              ? _buildBetaBanner(scheme, l10n)
              : null,
          aiFloatingPanel: useDesktopAiDock
              ? (_aiPanelCollapsed
                    ? _buildAiCollapsedFab(context, scheme)
                    : _buildAiPanel(context))
              : null,
          aiFloatingWidth: _aiPanelCollapsed ? 56 : _aiPanelWidth,
          aiFloatingHeight: _aiPanelCollapsed ? 56 : _aiPanelHeight,
          aiFloatingShowResizeHandles: useDesktopAiDock && !_aiPanelCollapsed,
          onResizeAiPanelWidth: useDesktopAiDock && !_aiPanelCollapsed
              ? (d) {
                  final maxW = (width * 0.5).clamp(300.0, 720.0);
                  setState(() {
                    _aiPanelWidth = (_aiPanelWidth - d).clamp(280.0, maxW);
                  });
                  unawaited(
                    widget.appSettings.setAiChatPanelWidth(_aiPanelWidth),
                  );
                }
              : null,
          onResizeAiPanelHeight: useDesktopAiDock && !_aiPanelCollapsed
              ? (d) {
                  setState(() {
                    _aiPanelHeight = (_aiPanelHeight + d).clamp(
                      320.0,
                      height * 0.85,
                    );
                  });
                  unawaited(
                    widget.appSettings.setAiChatPanelHeight(_aiPanelHeight),
                  );
                }
              : null,
          collabFloatingPanel: useDesktopCollabDock
              ? (_collabPanelCollapsed
                    ? _buildCollabCollapsedFab(context, scheme)
                    : _buildCollabDockPanel(context))
              : null,
          collabFloatingWidth: _collabPanelCollapsed ? 56 : _collabPanelWidth,
          collabFloatingHeight: _collabPanelCollapsed ? 56 : _collabPanelHeight,
          collabFloatingShowResizeHandles:
              useDesktopCollabDock && !_collabPanelCollapsed,
          onResizeCollabPanelWidth:
              useDesktopCollabDock && !_collabPanelCollapsed
              ? (d) {
                  final maxW = (width * 0.5).clamp(300.0, 720.0);
                  setState(() {
                    _collabPanelWidth = (_collabPanelWidth + d).clamp(
                      280.0,
                      maxW,
                    );
                  });
                }
              : null,
          onResizeCollabPanelHeight:
              useDesktopCollabDock && !_collabPanelCollapsed
              ? (d) {
                  setState(() {
                    _collabPanelHeight = (_collabPanelHeight + d).clamp(
                      320.0,
                      height * 0.85,
                    );
                  });
                }
              : null,
          overlay: _showQuillWorkspaceTour
              ? _buildQuillWorkspaceTourCard(theme, scheme, l10n)
              : null,
        ),
        floatingActionButton: compact && page != null
            ? Padding(
                padding: EdgeInsets.only(right: 0),
                child: _wrapWithMobileDockFabsIfNeeded(
                  aiEnabled: useMobileAiDock,
                  collabEnabled: useMobileCollabFab,
                  l10n: l10n,
                  child: verticalMobileWorkspace
                      ? (_mobileEditMode
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FloatingActionButton.small(
                                    heroTag: 'mobile_add_block_fab',
                                    onPressed: () =>
                                        _addBlockToCurrentPage(compact: true),
                                    child: const Icon(Icons.add_rounded),
                                  ),
                                  const SizedBox(height: 12),
                                  FloatingActionButton.extended(
                                    heroTag: 'mobile_done_edit_fab',
                                    onPressed: () {
                                      FocusScope.of(context).unfocus();
                                      setState(() => _mobileEditMode = false);
                                    },
                                    icon: const Icon(Icons.check_rounded),
                                    label: Text(l10n.mobileFabDone),
                                  ),
                                ],
                              )
                            : FloatingActionButton.extended(
                                heroTag: 'mobile_enter_edit_fab',
                                onPressed: () {
                                  setState(() => _mobileEditMode = true);
                                },
                                icon: const Icon(Icons.edit_rounded),
                                label: Text(l10n.mobileFabEdit),
                              ))
                      : (androidPhoneLayout
                            ? FloatingActionButton.extended(
                                heroTag: 'mobile_add_block_extended_fab',
                                onPressed: () =>
                                    _addBlockToCurrentPage(compact: true),
                                icon: const Icon(Icons.add_rounded),
                                label: Text(l10n.mobileFabAddBlock),
                              )
                            : FloatingActionButton(
                                heroTag: 'mobile_add_block_fab_square',
                                onPressed: () =>
                                    _addBlockToCurrentPage(compact: true),
                                child: const Icon(Icons.add_rounded),
                              )),
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

Future<_WorkspaceActionEntry?> _showWorkspaceActionsMenu({
  required BuildContext anchorContext,
  required List<_WorkspaceActionEntry> actions,
}) async {
  final theme = Theme.of(anchorContext);
  final scheme = theme.colorScheme;

  final buttonBox = anchorContext.findRenderObject() as RenderBox?;
  final overlayBox =
      Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
  if (buttonBox == null || overlayBox == null) return null;

  final buttonRect =
      buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
      buttonBox.size;
  final position = RelativeRect.fromRect(
    buttonRect,
    Offset.zero & overlayBox.size,
  );

  final maxW = math.min(420.0, overlayBox.size.width - 24.0);
  final menuW = maxW.clamp(280.0, 420.0);
  final maxH = math.min(560.0, overlayBox.size.height - 24.0);

  return showMenu<_WorkspaceActionEntry>(
    context: anchorContext,
    position: position,
    constraints: BoxConstraints.tightFor(width: menuW),
    items: [
      PopupMenuItem<_WorkspaceActionEntry>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: BlockEditorFloatingPanel(
            scheme: scheme,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                    child: Text(
                      AppLocalizations.of(
                        anchorContext,
                      ).workspaceMoreActionsTooltip,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: actions.length,
                      itemBuilder: (ctx, i) {
                        final a = actions[i];
                        final enabled = a.enabled;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: scheme.surfaceContainerLow.withValues(
                              alpha: 0.55,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: enabled
                                  ? () => Navigator.pop(ctx, a)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        a.icon,
                                        size: 20,
                                        color: enabled
                                            ? scheme.onSurface
                                            : scheme.onSurfaceVariant
                                                  .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        a.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: enabled
                                                  ? scheme.onSurface
                                                  : scheme.onSurfaceVariant
                                                        .withValues(alpha: 0.6),
                                            ),
                                      ),
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
            ),
          ),
        ),
      ),
    ],
  );
}
