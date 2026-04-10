import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_settings.dart';
import '../../app/folio_in_app_shortcuts.dart';
import '../../app/ui_tokens.dart';
import '../../app/widgets/folio_cloud_ai_ink_dialog.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_feedback.dart';
import '../../models/folio_page.dart';
import '../../models/block.dart';
import '../../models/folio_columns_data.dart';
import '../../models/folio_template_button_data.dart';
import '../../models/folio_toggle_data.dart';
import '../../services/ai/ai_types.dart';
import '../../services/ai/folio_cloud_ai_service.dart';
import '../../services/cloud_account/cloud_account_controller.dart';
import '../../services/folio_cloud/folio_cloud_checkout.dart';
import '../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../services/folio_cloud/folio_cloud_publish.dart';
import '../../services/folio_cloud/folio_page_html_export.dart';
import '../../services/device_sync/device_sync_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/run2doc/run2doc_markdown_codec.dart';
import '../../session/vault_session.dart';
import '../settings/folio_cloud_subscription_pitch_page.dart';
import '../settings/settings_page.dart';
import 'widgets/ai_typing_indicator.dart';
import 'widgets/ai_typewriter_message.dart';
import 'widgets/block_editor.dart';
import 'widgets/block_editor_support_widgets.dart';
import 'widgets/block_type_catalog.dart';
import 'widgets/page_history_sheet.dart';
import 'widgets/mermaid_markdown_builder.dart';
import 'widgets/sidebar.dart';
import 'widgets/page_outline_panel.dart';
import 'widgets/workspace_editor_surface.dart';
import 'widgets/workspace_shell.dart';

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

enum _AiContextItemKind { currentPage, page, file, addFile }

enum _AiContextMenuView { root, pages }

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
  late String _attachmentsBoundChatId;
  bool _aiChatBusy = false;
  AiTokenUsage? _lastChatTokenUsage;
  String _aiInkEstimateOperationKind = 'chat_turn';
  double _aiPanelWidth = 360;
  bool _aiPanelCollapsed = false;
  bool _showQuillWorkspaceTour = false;
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

  final GlobalKey<BlockEditorState> _blockEditorKey =
      GlobalKey<BlockEditorState>();

  VaultSession get _s => widget.session;
  AiChatThreadData get _activeChat => _s.activeAiChat;

  void _snack(String message, {bool error = false}) {
    if (!mounted || message.trim().isEmpty) return;
    showFolioSnack(context, message, error: error);
  }

  String _t(String es, String en) {
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    return lang.startsWith('es') ? es : en;
  }

  int _inkCostForOperationKind(String kind) {
    switch (kind) {
      case 'rewrite_block':
        return 1;
      case 'summarize_selection':
        return 1;
      case 'extract_tasks':
        return 2;
      case 'summarize_page':
        return 2;
      case 'generate_insert':
        return 4;
      case 'generate_page':
        return 6;
      case 'edit_page_panel':
        return 3;
      case 'agent_main':
        return 8;
      case 'agent_followup':
        return 3;
      case 'chat_turn':
      default:
        return 2;
    }
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
    final isCloudProvider = widget.appSettings.aiProvider == AiProvider.folioCloud;
    if (!isCloudProvider) return;
    final next = _estimateInkOperationKindForChat(
      text: _chatInputController.text,
      hasScopePage: _s.selectedPageId != null,
    );
    if (next == _aiInkEstimateOperationKind) return;
    setState(() => _aiInkEstimateOperationKind = next);
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

  Future<void> _saveCurrentPageAsTemplate() async {
    final page = _s.selectedPage;
    if (page == null) return;
    final l10n = AppLocalizations.of(context);
    String name = page.title.isNotEmpty ? page.title : l10n.untitledFallback;
    String description = '';
    String category = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FolioDialog(
          title: Text(l10n.saveAsTemplateTitle),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.templateNameHint),
                  controller: TextEditingController(text: name),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.templateDescriptionHint,
                  ),
                  onChanged: (v) => description = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.templateCategoryHint,
                  ),
                  onChanged: (v) => category = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    _s.savePageAsTemplate(
      page.id,
      name: name.trim().isNotEmpty ? name.trim() : null,
      description: description.trim(),
      category: category.trim(),
    );
    if (!mounted) return;
    _snack(l10n.templateSaved);
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

  String _suggestWebSlugFromTitle(String title) {
    var s = title.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'^-+|-+$'), '');
    if (s.isEmpty) return 'page';
    if (s.length > 48) {
      s = s.substring(0, 48).replaceAll(RegExp(r'-+$'), '');
    }
    return s.isEmpty ? 'page' : s;
  }

  Future<void> _publishCurrentPageToWeb() async {
    final page = _s.selectedPage;
    if (page == null || _s.state != VaultFlowState.unlocked) return;
    if (Firebase.apps.isEmpty) {
      _snack('Firebase no está disponible.');
      return;
    }
    if (!widget.cloudAccountController.isSignedIn) {
      _snack('Inicia sesión en la cuenta en la nube (Ajustes) para publicar.');
      return;
    }
    if (!widget.folioCloudEntitlements.snapshot.canPublishToWeb) {
      _snack(
        'Tu plan no incluye publicación web o la suscripción no está activa.',
      );
      return;
    }
    final slugController = TextEditingController(
      text: _suggestWebSlugFromTitle(page.title),
    );
    final snap = widget.folioCloudEntitlements.snapshot;
    try {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final l10n = AppLocalizations.of(ctx);
          return AlertDialog(
            title: const Text('Publicar en la web'),
            content: TextField(
              controller: slugController,
              decoration: const InputDecoration(
                labelText: 'URL (slug)',
                hintText: 'mi-nota',
                helperText:
                    'Letras, números y guiones. Quedará en la URL pública.',
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
                child: const Text('Publicar'),
              ),
            ],
          );
        },
      );
      if (go != true || !mounted) return;
      final slug = slugController.text.trim();
      if (slug.isEmpty) {
        _snack('Slug vacío.');
        return;
      }
      String? appIconDataUri;
      try {
        final data = await rootBundle.load('assets/icons/folio.ico');
        appIconDataUri =
            'data:image/x-icon;base64,${base64Encode(data.buffer.asUint8List())}';
      } catch (_) {}
      final html = folioPageExportHtmlDocument(
        page,
        appIconDataUri: appIconDataUri,
      );
      final res = await publishHtmlPage(
        slug: slug,
        html: html,
        entitlementSnapshot: snap,
      );
      if (!mounted) return;
      _snack('Publicado: ${res.publicUrl}');
      await launchUrl(res.publicUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) _snack('No se pudo publicar: $e');
    } finally {
      slugController.dispose();
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
                            final shouldAnimate = !isUser &&
                                _aiTypewriterActiveMessageKeys.contains(msgKey);
                            if (!shouldAnimate) {
                              return _buildMarkdownMessage(
                                context: ctx,
                                content: target,
                                isUser: isUser,
                                textColor: textColor,
                              );
                            }
                            final baseStyle = Theme.of(ctx)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: textColor,
                                  height: 1.35,
                                );
                            return FolioAiTypewriterMessage(
                              fullText: _normalizeHtmlForChat(target),
                              style: baseStyle ??
                                  TextStyle(
                                    color: textColor,
                                    height: 1.35,
                                  ),
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
      items.add(
        _AiContextItem(
          kind: _AiContextItemKind.file,
          id: path,
          label: path.split(RegExp(r'[/\\]')).last,
          path: path,
        ),
      );
    }
    return items;
  }

  List<_AiContextItem> _buildAiContextSuggestions(
    AppLocalizations l10n,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (_aiContextMenuView == _AiContextMenuView.root) {
      return <_AiContextItem>[
        _AiContextItem(
          kind: _AiContextItemKind.addFile,
          id: '__add_file__',
          label: l10n.aiContextAddFile,
        ),
        _AiContextItem(
          kind: _AiContextItemKind.page,
          id: '__open_pages__',
          label: l10n.aiContextAddPage,
        ),
      ];
    }
    final suggestions = <_AiContextItem>[
      _AiContextItem(
        kind: _AiContextItemKind.currentPage,
        id: '__current_page__',
        label: _s.selectedPage?.title.isNotEmpty == true
            ? l10n.aiContextCurrentPageChip(_s.selectedPage!.title)
            : l10n.aiContextCurrentPageFallback,
      ),
      ..._s.pages.map(
        (page) => _AiContextItem(
          kind: _AiContextItemKind.page,
          id: page.id,
          label: page.title.trim().isEmpty ? l10n.untitledFallback : page.title,
        ),
      ),
    ];
    if (needle.isEmpty) return suggestions.take(8).toList();
    return suggestions
        .where((item) => item.label.toLowerCase().contains(needle))
        .take(8)
        .toList();
  }

  bool _chatInputHasContextTrigger() {
    final value = _chatInputController.value;
    final text = value.text;
    final selection = value.selection;
    if (!selection.isValid) return false;
    final caret = selection.baseOffset;
    if (caret < 0 || caret > text.length) return false;
    final prefix = text.substring(0, caret);
    final match = RegExp(r'(^|\s)@([^\s@]*)$').firstMatch(prefix);
    if (match == null) return false;
    _aiContextQuery = match.group(2) ?? '';
    _aiContextMenuView = _AiContextMenuView.pages;
    return true;
  }

  void _hideAiContextMenu() {
    _aiContextMenuOverlay?.remove();
    _aiContextMenuOverlay = null;
    _aiContextMenuPinned = false;
    _aiContextMenuView = _AiContextMenuView.root;
  }

  void _showAiContextMenu({String initialQuery = '', bool pinned = false}) {
    _aiContextQuery = initialQuery;
    _aiContextMenuPinned = pinned;
    _aiContextMenuSelectedIndex = 0;
    _aiContextMenuUsingKeyboard = false;
    final l10n = AppLocalizations.of(context);
    final suggestions = _buildAiContextSuggestions(l10n, _aiContextQuery);
    if (suggestions.isEmpty) {
      _hideAiContextMenu();
      return;
    }
    _aiContextMenuOverlay?.remove();
    _aiContextMenuOverlay = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _hideAiContextMenu(),
                ),
              ),
              CompositedTransformFollower(
                link: _aiComposerLayerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.bottomLeft,
                offset: const Offset(0, -8),
                child: Material(
                  elevation: 8,
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(FolioRadius.lg),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 320,
                      maxHeight: 280,
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final item = suggestions[index];
                        final alreadySelected =
                            item.kind == _AiContextItemKind.page &&
                            item.id != '__open_pages__' &&
                            _activeChat.contextPageIds.contains(item.id);
                        final isKeyboardSelected =
                            _aiContextMenuUsingKeyboard &&
                            index == _aiContextMenuSelectedIndex;
                        final bgColor = isKeyboardSelected
                            ? scheme.primaryContainer.withValues(alpha: 0.3)
                            : Colors.transparent;
                        return MouseRegion(
                          onEnter: (_) {
                            if (_aiContextMenuUsingKeyboard) {
                              setState(() {
                                _aiContextMenuSelectedIndex = index;
                                _aiContextMenuUsingKeyboard = false;
                              });
                            }
                          },
                          child: Container(
                            color: bgColor,
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                alreadySelected
                                    ? Icons.check_rounded
                                    : _iconForAiContextItem(item.kind),
                                size: 18,
                              ),
                              title: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: item.id == '__open_pages__'
                                  ? const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                    )
                                  : null,
                              onTap: () {
                                _aiContextMenuUsingKeyboard = false;
                                _applyAiContextSuggestion(item);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_aiContextMenuOverlay!);
  }

  void _updateAiContextMenu() {
    if (_aiContextMenuPinned) {
      _showAiContextMenu(initialQuery: _aiContextQuery, pinned: true);
      return;
    }
    if (!_chatInputFocusNode.hasFocus || !_chatInputHasContextTrigger()) {
      _hideAiContextMenu();
      return;
    }
    _showAiContextMenu(initialQuery: _aiContextQuery);
    _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      final text = _chatInputController.text;
      if (text != _chatDraft) {
        setState(() => _chatDraft = text);
      }
    });
  }

  IconData _iconForAiContextItem(_AiContextItemKind kind) {
    switch (kind) {
      case _AiContextItemKind.currentPage:
        return Icons.menu_book_rounded;
      case _AiContextItemKind.page:
        return Icons.description_outlined;
      case _AiContextItemKind.file:
        return Icons.attach_file_rounded;
      case _AiContextItemKind.addFile:
        return Icons.add_circle_outline_rounded;
    }
  }

  Future<void> _applyAiContextSuggestion(_AiContextItem item) async {
    switch (item.kind) {
      case _AiContextItemKind.currentPage:
        _s.setActiveAiChatIncludePageContext(true);
        _s.setActiveAiChatContextPageIds(const []);
        _showAiContextMenu(
          initialQuery: _aiContextQuery,
          pinned: _aiContextMenuPinned,
        );
        break;
      case _AiContextItemKind.page:
        if (item.id == '__open_pages__') {
          _aiContextMenuView = _AiContextMenuView.pages;
          _showAiContextMenu(pinned: true);
          return;
        }
        final next = <String>{..._activeChat.contextPageIds, item.id}.toList();
        _s.setActiveAiChatIncludePageContext(true);
        _s.setActiveAiChatContextPageIds(next);
        _showAiContextMenu(initialQuery: _aiContextQuery, pinned: true);
        break;
      case _AiContextItemKind.file:
        break;
      case _AiContextItemKind.addFile:
        await _pickAiAttachments();
        _showAiContextMenu(pinned: true);
        break;
    }
    if (_aiContextMenuView == _AiContextMenuView.pages) {
      final value = _chatInputController.value;
      final text = value.text;
      final selection = value.selection;
      if (selection.isValid) {
        final caret = selection.baseOffset;
        final prefix = text.substring(0, caret);
        final match = RegExp(r'(^|\s)@([^\s@]*)$').firstMatch(prefix);
        if (match != null) {
          final replaceStart = match.start + (match.group(1)?.length ?? 0);
          final newText = text.replaceRange(replaceStart, caret, '');
          _chatInputController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: replaceStart),
          );
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _openAiContextPickerFromButton() {
    _chatInputFocusNode.requestFocus();
    _aiContextMenuView = _AiContextMenuView.root;
    _showAiContextMenu(pinned: true);
  }

  void _removeAiContextItem(_AiContextItem item) {
    switch (item.kind) {
      case _AiContextItemKind.currentPage:
        _s.setActiveAiChatIncludePageContext(false);
        _s.setActiveAiChatContextPageIds(const []);
        break;
      case _AiContextItemKind.page:
        final next = List<String>.from(_activeChat.contextPageIds)
          ..remove(item.id);
        if (next.isEmpty) {
          _s.setActiveAiChatContextPageIds(const []);
          _s.setActiveAiChatIncludePageContext(false);
        } else {
          _s.setActiveAiChatIncludePageContext(true);
          _s.setActiveAiChatContextPageIds(next);
        }
        break;
      case _AiContextItemKind.file:
        setState(() => _aiAttachmentPaths.remove(item.id));
        _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
        break;
      case _AiContextItemKind.addFile:
        break;
    }
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
    _chatInputController.addListener(_updateAiContextMenu);
    _chatInputFocusNode.addListener(_updateAiContextMenu);
    widget.folioCloudEntitlements.addListener(_onFolioCloudEntitlements);
    _syncTitleFromSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowQuillWorkspaceTour();
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
    if (mounted) setState(() {});
  }

  void _scheduleAiChatScrollToBottom() {
    final controller =
        _mobileSheetChatScroll ?? _aiChatScrollController;
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
    final w = MediaQuery.sizeOf(context).width;
    final androidMobile = FolioAdaptive.shouldUseMobileWorkspace(w);
    final compact =
        w < FolioDesktop.compactBreakpoint || androidMobile;
    final aiOn = widget.appSettings.isAiRuntimeEnabled && _s.aiEnabled;
    setState(() {
      if (aiOn && !compact) {
        _aiPanelCollapsed = false;
      }
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
    final compact =
        w < FolioDesktop.compactBreakpoint || androidMobile;
    final aiOn = widget.appSettings.isAiRuntimeEnabled && _s.aiEnabled;
    setState(() {
      if (aiOn && !compact) {
        _aiPanelCollapsed = false;
      }
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
    setState(() => _folioCloudCheckoutBusy = true);
    try {
      final uri = await createFolioCheckoutUri(FolioCheckoutKind.folioCloudMonthly);
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
        _snack(_t('No se pudo abrir el enlace.', 'Could not open the link.'), error: true);
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
        builder: (_) => BlockTypePickerSheet(catalog: blockTypeCatalog),
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
          child: BlockTypePickerSheet(catalog: blockTypeCatalog),
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

    // Handle keyboard navigation when context menu is open
    if (_aiContextMenuOverlay != null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _aiContextMenuSelectedIndex = math.max(
            0,
            _aiContextMenuSelectedIndex - 1,
          );
          _aiContextMenuUsingKeyboard = true;
        });
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final l10n = AppLocalizations.of(context);
        final suggestions = _buildAiContextSuggestions(l10n, _aiContextQuery);
        setState(() {
          _aiContextMenuSelectedIndex = math.min(
            suggestions.length - 1,
            _aiContextMenuSelectedIndex + 1,
          );
          _aiContextMenuUsingKeyboard = true;
        });
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final l10n = AppLocalizations.of(context);
        final suggestions = _buildAiContextSuggestions(l10n, _aiContextQuery);
        if (_aiContextMenuSelectedIndex >= 0 &&
            _aiContextMenuSelectedIndex < suggestions.length) {
          _applyAiContextSuggestion(suggestions[_aiContextMenuSelectedIndex]);
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideAiContextMenu();
        return KeyEventResult.handled;
      }
    }

    // Regular enter key handling
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
    // Recalcular estimación tras limpiar, para que no quede “pegada”.
    _updateInkEstimateFromComposer();
    _s.appendMessageToActiveAiChat(
      AiChatMessage.now(role: 'user', content: text),
    );
    try {
      final outcome = await _runAiFromChat(text, _activeChat.messages);
      if (!mounted) return;
      setState(() => _lastChatTokenUsage = outcome.usage);
      _s.appendMessageToActiveAiChat(
        AiChatMessage.now(role: 'assistant', content: outcome.reply),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (e is FolioCloudAiException && e.isInkExhausted) {
        await showFolioCloudAiInkExhaustedDialog(
          context,
          onOpenSettings: _openSettings,
          onOpenFolioCloudPitch: _openFolioCloudSubscriptionPitch,
        );
      } else {
        _snack(l10n.aiErrorWithDetails(e), error: true);
      }
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
    final isCloudProvider = widget.appSettings.aiProvider == AiProvider.folioCloud;
    final op = isCloudProvider ? _aiInkEstimateOperationKind : null;
    return _s.agentChatWithAi(
      messages: threadMessages,
      prompt: t,
      scopePageId: _s.selectedPageId,
      includePageContext: _activeChat.includePageContext,
      contextPageIds: _activeChat.contextPageIds,
      attachments: attachments,
      languageCode: languageCode,
      cloudInkOperation: op,
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
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
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

  Widget _buildAiCollapsedFab(BuildContext context, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.aiShowPanel,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _aiPanelCollapsed = false),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              Icons.chat_bubble_rounded,
              color: scheme.onPrimaryContainer,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMobileAiChatSheet() async {
    if (!mounted) return;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.38,
            maxChildSize: 0.98,
            expand: false,
            builder: (ctx, scrollController) {
              _mobileSheetChatScroll = scrollController;
              final theme = Theme.of(ctx);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
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
                            borderRadius: BorderRadius.circular(999),
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: _buildAiPanel(
                          ctx,
                          onRequestClosePanel: () =>
                              Navigator.of(sheetContext).pop(),
                          chatListScrollController: scrollController,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      _mobileSheetChatScroll = null;
    }
  }

  Widget _wrapWithMobileQuillFabIfNeeded({
    required bool enabled,
    required AppLocalizations l10n,
    required Widget child,
  }) {
    if (!enabled) return child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'mobile_quill_chat_fab',
          tooltip: l10n.aiShowPanel,
          onPressed: () => unawaited(_openMobileAiChatSheet()),
          child: const Icon(Icons.chat_bubble_rounded),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildAiPanel(
    BuildContext context, {
    VoidCallback? onRequestClosePanel,
    ScrollController? chatListScrollController,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isCloudProvider = widget.appSettings.aiProvider == AiProvider.folioCloud;
    final showInkInChat = isCloudProvider &&
        widget.appSettings.isAiRuntimeEnabled &&
        widget.folioCloudEntitlements.snapshot.canUseCloudAi;
    final inkSnap = widget.folioCloudEntitlements.snapshot.ink;
    const lowInkThreshold = 20;
    final estInkCost = _inkCostForOperationKind(_aiInkEstimateOperationKind);
    final inkLooksLow = showInkInChat && inkSnap.totalInk > 0 && inkSnap.totalInk <= lowInkThreshold;
    final inkLooksEmpty = showInkInChat && inkSnap.totalInk <= 0;

    String providerLabel() {
      switch (widget.appSettings.aiProvider) {
        case AiProvider.none:
          return _t('Sin configurar', 'Not set');
        case AiProvider.folioCloud:
          return 'Folio Cloud';
        case AiProvider.ollama:
          return 'Ollama';
        case AiProvider.lmStudio:
          return 'LM Studio';
      }
    }

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: ColoredBox(
        color: scheme.surface,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surfaceContainerHighest,
                    scheme.surfaceContainerHigh,
                  ],
                ),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                borderRadius: BorderRadius.circular(FolioRadius.xl),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primaryContainer,
                          scheme.tertiaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 22,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    l10n.aiBetaBadge,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    border: Border.all(
                                      color: scheme.outlineVariant.withValues(alpha: 0.40),
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isCloudProvider ? Icons.cloud_outlined : Icons.computer_outlined,
                                        size: 14,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        providerLabel(),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _aiPanelContextSubtitle(l10n),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.95,
                            ),
                            height: 1.35,
                          ),
                        ),
                        if (showInkInChat) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Tooltip(
                                message: l10n.aiChatInkBreakdownTooltip(
                                  inkSnap.monthlyBalance,
                                  inkSnap.purchasedBalance,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: inkLooksLow
                                        ? scheme.tertiaryContainer.withValues(alpha: 0.65)
                                        : scheme.primary.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.water_drop_outlined,
                                        size: 16,
                                        color: inkLooksLow
                                            ? scheme.onTertiaryContainer
                                            : scheme.primary.withValues(alpha: 0.92),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        l10n.aiChatInkRemaining(inkSnap.totalInk),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: inkLooksLow
                                              ? scheme.onTertiaryContainer
                                              : scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (inkLooksEmpty) ...[
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: _openSettings,
                              icon: const Icon(Icons.shopping_bag_outlined),
                              label: Text(_t('Comprar tinta', 'Buy ink')),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.aiHidePanel,
                    onPressed: () {
                      if (onRequestClosePanel != null) {
                        onRequestClosePanel();
                      } else {
                        setState(() => _aiPanelCollapsed = true);
                      }
                    },
                    icon: const Icon(Icons.unfold_less_rounded),
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
                          visualDensity: VisualDensity.compact,
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
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(FolioRadius.xl),
                ),
                child: Builder(
                  builder: (context) {
                    final msgs = _activeChat.messages;
                    final showChatList = msgs.isNotEmpty || _aiChatBusy;
                    if (!showChatList) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(28),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withValues(
                                          alpha: 0.10,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.forum_outlined,
                                        color: scheme.primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.aiChatEmptyHint,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.55,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    FilledButton.tonal(
                                      onPressed: () {
                                        _chatInputFocusNode.requestFocus();
                                      },
                                      child: Text(
                                        l10n.aiChatEmptyFocusComposer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                    final typingExtra = _aiChatBusy ? 1 : 0;
                    return ListView.builder(
                      controller:
                          chatListScrollController ?? _aiChatScrollController,
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                      itemCount: msgs.length + typingExtra,
                      itemBuilder: (context, i) {
                        if (_aiChatBusy && i == msgs.length) {
                          return _buildAiTypingRow(theme, scheme, l10n);
                        }
                        return _buildAiMessageRow(
                          context,
                          msgs[i],
                          i,
                          theme,
                          scheme,
                          l10n,
                        );
                      },
                    );
                  },
                ),
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
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.surfaceContainerHighest, scheme.surface],
                  ),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.40),
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showInkInChat) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 8,
                          top: 2,
                          bottom: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.water_drop_outlined,
                              size: 16,
                              color: inkLooksLow
                                  ? scheme.tertiary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _t(
                                  'Coste estimado: $estInkCost gotas.',
                                  'Estimated cost: $estInkCost ink.',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            if (inkLooksLow || inkLooksEmpty) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _openSettings,
                                child: Text(_t('Tinta', 'Ink')),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    Builder(
                      builder: (context) {
                        final items = _buildActiveAiContextItems(l10n);
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              top: 4,
                            ),
                            child: Text(
                              l10n.aiContextComposerHint,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            top: 4,
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: items
                                .map(
                                  (item) => InputChip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: Icon(
                                      _iconForAiContextItem(item.kind),
                                      size: 16,
                                    ),
                                    label: Text(item.label),
                                    onDeleted:
                                        item.kind == _AiContextItemKind.addFile
                                        ? null
                                        : () => _removeAiContextItem(item),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    ),
                    CompositedTransformTarget(
                      link: _aiComposerLayerLink,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: _openAiContextPickerFromButton,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
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
                                    onTap: _updateAiContextMenu,
                                    onChanged: (_) {
                                      _updateAiContextMenu();
                                      _updateInkEstimateFromComposer();
                                    },
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: l10n.aiInputHintCopilot,
                                      helperText: l10n.aiContextComposerHelper,
                                      helperMaxLines: 2,
                                      isDense: true,
                                      hintStyle: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant
                                                .withValues(alpha: 0.85),
                                          ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                      ),
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
    final effectiveSidebarW = compact
        ? 0.0
        : (widget.appSettings.workspaceSidebarCollapsed
              ? (_sidebarPeek ? widget.appSettings.workspaceSidebarWidth : 0.0)
              : widget.appSettings.workspaceSidebarWidth);
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
          onSearch: widget.onOpenSearch,
          onForceSync: _forceSyncNow,
          onOpenSettings: _openSettings,
          onLock: () => _s.lock(),
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
            label: l10n.importMarkdownPage,
            icon: Icons.file_upload_outlined,
            onPressed: _importMarkdownFile,
            forcePrimary: true,
          ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'export_md',
              label: l10n.exportMarkdownPage,
              icon: Icons.file_download_outlined,
              onPressed: _exportCurrentPageToMarkdown,
            ),
          if (page != null)
            _WorkspaceActionEntry(
              id: 'publish_web',
              label: 'Publicar en la web',
              icon: Icons.public_rounded,
              onPressed: _publishCurrentPageToWeb,
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
              icon: Icons.tab_unselected_rounded,
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
          if (canToggleAi)
            _WorkspaceActionEntry(
              id: 'toggle_ai',
              label: useMobileAiDock
                  ? l10n.aiShowPanel
                  : (_aiPanelCollapsed
 ? l10n.aiShowPanel
                        : l10n.aiHidePanel),
              icon: useMobileAiDock || _aiPanelCollapsed
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.unfold_less_rounded,
              onPressed: () {
                if (useMobileAiDock) {
                  unawaited(_openMobileAiChatSheet());
                } else {
                  setState(() => _aiPanelCollapsed = !_aiPanelCollapsed);
                }
              },
              forcePrimary: true,
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
          ...primary.map(
            (action) => IconButton(
              tooltip: action.label,
              icon: Icon(action.icon),
              onPressed: action.enabled ? action.onPressed : null,
            ),
          ),
          if (overflow.isNotEmpty)
            PopupMenuButton<_WorkspaceActionEntry>(
              tooltip: l10n.workspaceMoreActionsTooltip,
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
      editor: page == null
          ? const SizedBox.shrink()
          : KeyedSubtree(
              key: ValueKey('${page.id}-${_s.contentEpoch}'),
              child: BlockEditor(
                key: _blockEditorKey,
                session: _s,
                appSettings: widget.appSettings,
                readOnlyMode: editorReadOnlyMode,
              ),
            ),
    );
    final editorContent = !compact && page != null
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: editorSurface),
              if (widget.appSettings.workspacePageOutlineVisible)
                PageOutlinePanel(
                  blocks: page.blocks,
                  scheme: scheme,
                  blockEditorKey: _blockEditorKey,
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
                }
              : null,
          overlay: _showQuillWorkspaceTour
              ? _buildQuillWorkspaceTourCard(theme, scheme, l10n)
              : null,
        ),
        floatingActionButton: compact && page != null
            ? Padding(
                padding: EdgeInsets.only(right: 0),
                child: _wrapWithMobileQuillFabIfNeeded(
                  enabled: useMobileAiDock,
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
                                    label: const Text('Listo'),
                                  ),
                                ],
                              )
                            : FloatingActionButton.extended(
                                heroTag: 'mobile_enter_edit_fab',
                                onPressed: () {
                                  setState(() => _mobileEditMode = true);
                                },
                                icon: const Icon(Icons.edit_rounded),
                                label: const Text('Editar'),
                              ))
                      : (androidPhoneLayout
                            ? FloatingActionButton.extended(
                                heroTag: 'mobile_add_block_extended_fab',
                                onPressed: () =>
                                    _addBlockToCurrentPage(compact: true),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Bloque'),
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
