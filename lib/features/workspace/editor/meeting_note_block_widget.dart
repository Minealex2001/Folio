import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/block.dart';
import '../../../models/folio_page.dart';
import '../../../models/meeting_note_bookmark.dart';
import '../../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../../services/meeting_note_metrics_service.dart';
import '../../../services/meeting_note_posthoc_transcription_manager.dart';
import '../../../services/meeting_note_preparation_service.dart';
import '../../../services/meeting_note_session_controller.dart';
import '../../../services/system_audio_service.dart';
import '../../../services/transcription_hardware_profile.dart';
import '../../../services/whisper_service.dart';
import '../../../session/vault_session.dart';
import 'folio_special_block_widgets.dart';
import 'meeting_note_live_assist_panel.dart';
import 'meeting_note_posthoc_dialog.dart';

class MeetingNoteBlockWidget extends StatefulWidget {
  const MeetingNoteBlockWidget({
    super.key,
    required this.block,
    required this.page,
    required this.session,
    required this.appSettings,
    required this.scheme,
    required this.resolvedFile,
    this.folioCloudEntitlements,
  });

  final FolioBlock block;
  final FolioPage page;
  final VaultSession session;
  final AppSettings appSettings;
  final ColorScheme scheme;
  final File? resolvedFile;
  final FolioCloudEntitlementsController? folioCloudEntitlements;

  @override
  State<MeetingNoteBlockWidget> createState() => _MeetingNoteBlockWidgetState();
}

enum _TranscriptionProvider { local, quillCloud }

class _MeetingNoteBlockWidgetState extends State<MeetingNoteBlockWidget> {
  static const List<_MeetingLanguageOption> _languageOptions = [
    _MeetingLanguageOption(code: 'auto', labelKey: 'meetingNoteLangAuto'),
    _MeetingLanguageOption(code: 'es', labelKey: 'meetingNoteLangEs'),
    _MeetingLanguageOption(code: 'en', labelKey: 'meetingNoteLangEn'),
    _MeetingLanguageOption(code: 'pt', labelKey: 'meetingNoteLangPt'),
    _MeetingLanguageOption(code: 'fr', labelKey: 'meetingNoteLangFr'),
    _MeetingLanguageOption(code: 'it', labelKey: 'meetingNoteLangIt'),
    _MeetingLanguageOption(code: 'de', labelKey: 'meetingNoteLangDe'),
  ];

  final _controller = MeetingNoteSessionController.instance;

  String _selectedLanguageCode = 'auto';
  bool _languageInitialized = false;
  _TranscriptionProvider _provider = _TranscriptionProvider.local;
  late TranscriptionHardwareSnapshot _hardwareSnapshot;
  bool _generateTranscription = true;
  String? _localIdleError;
  bool _generatingPrep = false;
  String? _prepError;
  bool _generatingChecklist = false;
  bool _generatingSummary = false;
  String? _summaryError;
  final Set<int> _materializingActionItem = {};

  /// Fase 16 (auditoría de gating local/cloud): confirmado una vez por
  /// sesión de este widget, igual que `MeetingNoteLiveAssistPanel`. Antes
  /// de esta fase, Prepare/Checklist/Summary llamaban al `AiService` activo
  /// sin pedir este opt-in cuando el proveedor era cloud — inconsistente
  /// con Live Assist/auto-trigger, que sí lo piden. Un único flag basta
  /// porque los tres viven en el mismo widget/sesión de edición.
  bool _cloudOptInConfirmed = false;

  @override
  void initState() {
    super.initState();
    _hardwareSnapshot = TranscriptionHardwareProfile.loadCached();
    _generateTranscription =
        widget.block.meetingNoteTranscriptionEnabled != false;
    _loadProviderFromBlock();
    _normalizeMeetingNoteProviderWithAi();
    _controller.addListener(_onSessionChanged);
  }

  @override
  void didUpdateWidget(MeetingNoteBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appSettings.isAiRuntimeEnabled !=
            widget.appSettings.isAiRuntimeEnabled ||
        oldWidget.block.meetingNoteProvider !=
            widget.block.meetingNoteProvider) {
      _loadProviderFromBlock();
      _normalizeMeetingNoteProviderWithAi();
    }
    if (oldWidget.block.meetingNoteTranscriptionEnabled !=
        widget.block.meetingNoteTranscriptionEnabled) {
      _generateTranscription =
          widget.block.meetingNoteTranscriptionEnabled != false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_languageInitialized) return;
    final localeCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    final supported = _languageOptions.any((o) => o.code == localeCode);
    _selectedLanguageCode = supported ? localeCode : 'auto';
    _languageInitialized = true;
  }

  @override
  void dispose() {
    _controller.removeListener(_onSessionChanged);
    // No detener la sesión: el worker sigue en proceso aparte.
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _isThisSession =>
      _controller.isSessionFor(widget.page.id, widget.block.id);

  MeetingNoteSessionState get _effectiveState {
    if (_isThisSession) return _controller.state;
    if (widget.resolvedFile != null ||
        (widget.block.url ?? '').trim().isNotEmpty ||
        widget.block.text.trim().isNotEmpty) {
      return MeetingNoteSessionState.completed;
    }
    return MeetingNoteSessionState.idle;
  }

  void _loadProviderFromBlock() {
    final raw = widget.block.meetingNoteProvider?.trim() ?? '';
    _provider = raw == 'quill_cloud'
        ? _TranscriptionProvider.quillCloud
        : _TranscriptionProvider.local;
  }

  void _normalizeMeetingNoteProviderWithAi() {
    if (_provider == _TranscriptionProvider.quillCloud &&
        !widget.appSettings.isAiRuntimeEnabled) {
      _provider = _TranscriptionProvider.local;
      widget.session.updateBlockMeetingNoteProvider(
        widget.page.id,
        widget.block.id,
        'local',
      );
    }
  }

  void _saveProviderToBlock(_TranscriptionProvider provider) {
    final value = provider == _TranscriptionProvider.quillCloud
        ? 'quill_cloud'
        : 'local';
    widget.session.updateBlockMeetingNoteProvider(
      widget.page.id,
      widget.block.id,
      value,
    );
  }

  bool get _folioCloudInkAvailable {
    final ent = widget.folioCloudEntitlements;
    if (ent == null) return false;
    return ent.snapshot.canUseCloudAi;
  }

  bool get _cloudTranscriptionAllowed =>
      widget.appSettings.isAiRuntimeEnabled && _folioCloudInkAvailable;

  bool get _effectiveCloudPostProcess =>
      _provider == _TranscriptionProvider.quillCloud &&
      _cloudTranscriptionAllowed &&
      _generateTranscription;

  bool get _runLocalWhisperDuringRecording =>
      _generateTranscription &&
      (_hardwareSnapshot.isLocalTranscriptionViable ||
          widget.appSettings.meetingNoteForceLocalTranscription);

  String _activeModelId() =>
      widget.appSettings.resolvedMeetingNoteWhisperModelId();

  String _activeModelLabel(AppLocalizations l10n) {
    final model = WhisperService.instance.modelById(_activeModelId());
    final id = model?.id ?? 'base';
    return switch (id) {
      'tiny' => l10n.meetingNoteModelTiny,
      'small' => l10n.meetingNoteModelSmall,
      'medium' => l10n.meetingNoteModelMedium,
      'turbo' => l10n.meetingNoteModelTurbo,
      _ => l10n.meetingNoteModelBase,
    };
  }

  String _selectedLanguageLabel(AppLocalizations l10n) {
    for (final o in _languageOptions) {
      if (o.code == _selectedLanguageCode) {
        return _resolveLanguageLabel(l10n, o.labelKey);
      }
    }
    return l10n.meetingNoteLangAuto;
  }

  String _resolveLanguageLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      'meetingNoteLangAuto' => l10n.meetingNoteLangAuto,
      'meetingNoteLangEs' => l10n.meetingNoteLangEs,
      'meetingNoteLangEn' => l10n.meetingNoteLangEn,
      'meetingNoteLangPt' => l10n.meetingNoteLangPt,
      'meetingNoteLangFr' => l10n.meetingNoteLangFr,
      'meetingNoteLangIt' => l10n.meetingNoteLangIt,
      'meetingNoteLangDe' => l10n.meetingNoteLangDe,
      _ => l10n.meetingNoteLangAuto,
    };
  }

  bool get _recordingAudioOnlyBadge =>
      !_generateTranscription ||
      (!_runLocalWhisperDuringRecording && !_effectiveCloudPostProcess);

  Color _recordingBadgeColor() {
    if (_recordingAudioOnlyBadge) return widget.scheme.tertiary;
    if (_provider == _TranscriptionProvider.quillCloud) {
      return widget.scheme.primary;
    }
    return widget.scheme.onSurfaceVariant;
  }

  String _recordingBadgeLabel(AppLocalizations l10n) {
    if (_recordingAudioOnlyBadge) return l10n.meetingNoteRecordingAudioOnlyBadge;
    if (_provider == _TranscriptionProvider.quillCloud) {
      return l10n.meetingNoteCloudRecordingBadge(_selectedLanguageLabel(l10n));
    }
    return l10n.meetingNoteRecordingBadge(
      _selectedLanguageLabel(l10n),
      _activeModelLabel(l10n),
    );
  }

  String get _displayTranscript {
    if (_isThisSession && _controller.transcript.isNotEmpty) {
      return _controller.transcript;
    }
    return widget.block.text;
  }

  String _recordingTranscriptCaption(AppLocalizations l10n) {
    if (!_generateTranscription) {
      return l10n.meetingNotePerNoteTranscriptionOffHint;
    }
    final t = _displayTranscript;
    if (t.isEmpty) return l10n.meetingNoteWaitingTranscription;
    return t;
  }

  // Colores estables por speaker (ciclan si hay más hablantes que colores).
  // Se reutiliza el mismo color para "Speaker N" en toda la sesión para que
  // el ojo pueda seguir a un hablante mientras el transcript sigue creciendo.
  static const List<Color> _speakerPalette = [
    Color(0xFF6750A4), // primary-like violeta
    Color(0xFF2E7D32), // verde
    Color(0xFF9A5B00), // ámbar oscuro
    Color(0xFF00695C), // teal
    Color(0xFFAD1457), // magenta
    Color(0xFF1565C0), // azul
  ];

  Color _speakerColor(int speakerId) =>
      _speakerPalette[(speakerId - 1) % _speakerPalette.length];

  static final RegExp _speakerLinePrefix = RegExp(r'^Speaker (\d+): ');

  /// Construye el transcript con color por speaker cuando el texto sigue el
  /// formato `Speaker N: ...` (una o varias líneas). Si no hay etiquetas de
  /// speaker reconocibles, cae al texto plano sin colorear.
  Widget _buildColoredTranscript(String text, TextStyle? baseStyle) {
    final lines = text.split('\n');
    final hasSpeakerLabels = lines.any(
      (l) => _speakerLinePrefix.hasMatch(l),
    );
    if (!hasSpeakerLabels) {
      return SelectableText(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = _speakerLinePrefix.firstMatch(line);
      if (match != null) {
        final speakerId = int.tryParse(match.group(1) ?? '') ?? 1;
        spans.add(
          TextSpan(
            text: match.group(0),
            style: baseStyle?.copyWith(
              color: _speakerColor(speakerId),
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        spans.add(
          TextSpan(text: line.substring(match.end), style: baseStyle),
        );
      } else {
        spans.add(TextSpan(text: line, style: baseStyle));
      }
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: baseStyle));
    }
    return SelectableText.rich(TextSpan(children: spans));
  }

  String? _resolveRuntimeError(AppLocalizations l10n) {
    if (_localIdleError != null) return _localIdleError;
    if (!_isThisSession) return null;
    final code = _controller.runtimeErrorCode;
    if (code == null) return null;
    final detail = _controller.runtimeErrorDetail;
    return switch (code) {
      'audio_access' => l10n.meetingNoteAudioAccessError,
      'whisper_init' => l10n.meetingNoteWhisperInitError(detail ?? ''),
      'chunk_transcription' =>
        (detail != null && detail.isNotEmpty && detail != 'chunk_transcription')
            ? detail
            : l10n.meetingNoteChunkTranscriptionError,
      'worker_start' || 'worker_crashed' =>
        l10n.meetingNoteWorkerError(detail ?? ''),
      'stop_failed' => l10n.meetingNoteWorkerError(detail ?? ''),
      _ => detail ?? l10n.meetingNoteWorkerError(code),
    };
  }

  String? _resolveCloudFallback(AppLocalizations l10n) {
    if (!_isThisSession) return null;
    return switch (_controller.cloudFallbackNoticeCode) {
      'ink_exhausted' => l10n.meetingNoteCloudInkExhaustedNotice,
      'cloud_fallback' => l10n.meetingNoteCloudFallbackNotice,
      'cloud_upload_cancelled' => l10n.meetingNoteCloudUploadCancelledNotice,
      _ => null,
    };
  }

  String _formatDurationClock(Duration d) {
    final totalSeconds = d.inSeconds.clamp(0, 359999);
    final mm = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context);
    _hardwareSnapshot = TranscriptionHardwareProfile.loadCached();
    setState(() => _localIdleError = null);

    if (_controller.isActive && !_isThisSession) {
      setState(() => _localIdleError = l10n.meetingNoteAnotherSessionActive);
      return;
    }

    await _controller.start(
      session: widget.session,
      appSettings: widget.appSettings,
      pageId: widget.page.id,
      blockId: widget.block.id,
      generateTranscription: _generateTranscription,
      languageCode: _selectedLanguageCode,
      provider: _provider == _TranscriptionProvider.quillCloud
          ? 'quill_cloud'
          : 'local',
      runLocalWhisper: _runLocalWhisperDuringRecording,
      saveCloudChunks: _effectiveCloudPostProcess,
      modelId: _activeModelId(),
      entitlements: widget.folioCloudEntitlements,
    );

    if (!mounted) return;
    if (_controller.runtimeErrorCode == 'audio_access') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.meetingNoteMicrophoneAccessError)),
      );
    }
  }

  Future<void> _stopRecording() async {
    await _controller.stop();
  }

  bool get _prepAvailable => widget.appSettings.isAiRuntimeEnabled;

  /// Fase 15: consolida el patrón "TextButton.icon con spinner mientras
  /// carga" repetido por los botones Prepare/Checklist/Summary — mismo
  /// tamaño de spinner (14px, strokeWidth 2, color primary) en los tres,
  /// que antes se copiaba a mano en cada uno.
  Widget _loadingTextButton({
    required bool loading,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
  }) {
    return TextButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.scheme.primary,
              ),
            )
          : Icon(icon, size: 16),
      label: Text(label),
    );
  }

  /// Fase 16: opt-in explícito antes de la primera llamada IA cloud de la
  /// sesión (Prepare/Checklist/Summary comparten este flag) — mismo diálogo
  /// que `MeetingNoteLiveAssistPanel._ensureCloudOptIn`. Sin efecto si el
  /// proveedor activo es local.
  Future<bool> _ensureCloudOptIn() async {
    if (widget.appSettings.aiProvider != AiProvider.quillCloud ||
        _cloudOptInConfirmed) {
      return true;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.meetingNoteLiveAssistCloudOptInTitle),
        content: Text(l10n.meetingNoteLiveAssistCloudOptInBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.meetingNoteCancelUpload),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.meetingNoteLiveAssistCloudOptInConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    if (!mounted) return false;
    setState(() => _cloudOptInConfirmed = true);
    return true;
  }

  Future<void> _generatePrep() async {
    if (!await _ensureCloudOptIn()) return;
    setState(() {
      _generatingPrep = true;
      _prepError = null;
    });
    try {
      final result = await MeetingNotePreparationService.instance.generate(
        session: widget.session,
        pageId: widget.page.id,
        blockId: widget.block.id,
      );
      if (!mounted) return;
      setState(() {
        _generatingPrep = false;
        if (result == null) {
          _prepError = AppLocalizations.of(context).meetingNotePrepFailed;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generatingPrep = false;
        _prepError = AppLocalizations.of(context).meetingNotePrepFailed;
      });
    }
  }

  Future<void> _generateChecklist() async {
    if (!await _ensureCloudOptIn()) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _generatingChecklist = true);
    int inserted = 0;
    try {
      inserted = await MeetingNotePreparationService.instance.generateChecklist(
        session: widget.session,
        pageId: widget.page.id,
        blockId: widget.block.id,
      );
    } catch (_) {
      inserted = 0;
    }
    if (!mounted) return;
    setState(() => _generatingChecklist = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          inserted > 0
              ? l10n.meetingNoteChecklistGenerated(inserted)
              : l10n.meetingNotePrepFailed,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final content = switch (_effectiveState) {
      MeetingNoteSessionState.idle => _buildIdle(theme, l10n),
      MeetingNoteSessionState.setup => _buildSetup(theme),
      MeetingNoteSessionState.recording => _buildRecording(theme, l10n),
      MeetingNoteSessionState.cloudProcessing =>
        _buildCloudProcessing(theme, l10n),
      MeetingNoteSessionState.completed => _buildCompleted(theme, l10n),
    };
    final showRelatedPages =
        _effectiveState == MeetingNoteSessionState.idle ||
        _effectiveState == MeetingNoteSessionState.setup;
    // El bloque `meeting_note` se embebe dentro de un `Container` con
    // `decoration: BoxDecoration(color: ...)` en
    // `block_row_dispatch_meeting_note.dart` — un `DecoratedBox` intermedio
    // como ese oculta el fondo/ripple de cualquier `ListTile`/
    // `SwitchListTile` (Fase idle usa uno) porque pintan sobre el
    // `Material` ancestro más cercano, que sería el de más arriba en el
    // árbol, detrás del `DecoratedBox`. Un `Material` transparente aquí
    // resuelve el aviso de Flutter sin tocar el `Container` del dispatcher.
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showRelatedPages) _buildRelatedPagesRow(theme, l10n),
          content,
        ],
      ),
    );
  }

  // Fase 5 de la evolución de meeting_note: contexto — reutiliza
  // `VaultSession.backlinkPagesFor` (grafo de páginas ya existente, mismo
  // dato que expone la tool MCP `meeting_get_context`) en vez de un índice
  // nuevo. Solo informativo por ahora (sin navegación) — no hay un callback
  // de "abrir página" plumbeado hasta este widget.
  Widget _buildRelatedPagesRow(ThemeData theme, AppLocalizations l10n) {
    final related = widget.session.backlinkPagesFor(widget.page.id);
    if (related.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.meetingNoteRelatedPages,
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final p in related.take(6))
            Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text(
                p.title.isEmpty ? l10n.meetingNoteUntitledPage : p.title,
                style: theme.textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIdle(ThemeData theme, AppLocalizations l10n) {
    final runtimeError = _resolveRuntimeError(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.meetingNoteTitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: widget.scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (!SystemAudioService.isSupported)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.meetingNoteDesktopOnly,
              style: theme.textTheme.bodySmall?.copyWith(
                color: widget.scheme.error,
              ),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _generateTranscription,
          onChanged: (v) {
            setState(() => _generateTranscription = v);
            widget.session.updateBlockMeetingNoteTranscriptionEnabled(
              widget.page.id,
              widget.block.id,
              v ? null : false,
            );
          },
          title: Text(l10n.meetingNoteGenerateTranscription),
          subtitle: Text(
            l10n.meetingNoteGenerateTranscriptionSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: widget.scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_generateTranscription &&
            _provider == _TranscriptionProvider.local &&
            !_runLocalWhisperDuringRecording &&
            !_effectiveCloudPostProcess) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.meetingNoteLocalTranscriptionNotViable,
              style: theme.textTheme.labelSmall?.copyWith(
                color: widget.scheme.error,
              ),
            ),
          ),
        ],
        if (_generateTranscription && _cloudTranscriptionAllowed) ...[
          Text(
            l10n.meetingNoteTranscriptionProvider,
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<_TranscriptionProvider>(
            segments: [
              ButtonSegment(
                value: _TranscriptionProvider.local,
                label: Text(l10n.meetingNoteProviderLocal),
                icon: const Icon(Icons.computer_rounded, size: 16),
              ),
              ButtonSegment(
                value: _TranscriptionProvider.quillCloud,
                label: Text(l10n.meetingNoteProviderCloud),
                icon: const Icon(Icons.cloud_rounded, size: 16),
              ),
            ],
            selected: {_provider},
            onSelectionChanged: (selected) {
              final nextProvider = selected.first;
              setState(() => _provider = nextProvider);
              _saveProviderToBlock(nextProvider);
            },
          ),
          if (_provider == _TranscriptionProvider.quillCloud) ...[
            const SizedBox(height: 4),
            Text(
              l10n.meetingNoteProviderCloudCost,
              style: theme.textTheme.labelSmall?.copyWith(
                color: widget.scheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ] else if (_generateTranscription &&
            _folioCloudInkAvailable &&
            !widget.appSettings.isAiRuntimeEnabled) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.meetingNoteCloudRequiresAiEnabled,
              style: theme.textTheme.labelSmall?.copyWith(
                color: widget.scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (_prepAvailable) ...[
          if (widget.block.meetingNotePrepNotes?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: SelectableText(
                    widget.block.meetingNotePrepNotes!.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: widget.scheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          Wrap(
            spacing: 4,
            children: [
              _loadingTextButton(
                loading: _generatingPrep,
                onPressed: _generatePrep,
                icon: Icons.auto_awesome_outlined,
                label: widget.block.meetingNotePrepNotes?.trim().isNotEmpty == true
                    ? l10n.meetingNoteRegeneratePrep
                    : l10n.meetingNotePrepareMeeting,
              ),
              _loadingTextButton(
                loading: _generatingChecklist,
                onPressed: _generateChecklist,
                icon: Icons.checklist_rounded,
                label: l10n.meetingNoteGenerateChecklist,
              ),
            ],
          ),
          if (_prepError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _prepError!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: widget.scheme.error,
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
        FilledButton.tonalIcon(
          onPressed: SystemAudioService.isSupported ? _startRecording : null,
          icon: const Icon(Icons.mic_rounded),
          label: Text(l10n.meetingNoteStartRecording),
        ),
        const SizedBox(height: 8),
        if (_generateTranscription) ...[
          DropdownButtonFormField<String>(
            initialValue: _selectedLanguageCode,
            decoration: InputDecoration(
              labelText: l10n.meetingNoteTranscriptionLanguage,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: _languageOptions
                .map(
                  (o) => DropdownMenuItem<String>(
                    value: o.code,
                    child: Text(_resolveLanguageLabel(l10n, o.labelKey)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedLanguageCode = (value ?? 'auto').trim();
              });
            },
          ),
          const SizedBox(height: 8),
        ],
        Text(
          l10n.meetingNoteDevicesInSettings,
          style: theme.textTheme.labelSmall?.copyWith(
            color: widget.scheme.onSurfaceVariant,
          ),
        ),
        if (_generateTranscription) ...[
          const SizedBox(height: 4),
          Text(
            l10n.meetingNoteModelInSettings(_activeModelLabel(l10n)),
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (runtimeError != null) ...[
          const SizedBox(height: 8),
          Text(
            runtimeError,
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.scheme.error,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          !_generateTranscription
              ? l10n.meetingNoteGenerateTranscriptionSubtitle
              : _provider == _TranscriptionProvider.quillCloud &&
                      _cloudTranscriptionAllowed
                  ? l10n.meetingNoteProviderCloudCost
                  : l10n.meetingNoteDescription,
          style: theme.textTheme.labelSmall?.copyWith(
            color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSetup(ThemeData theme) {
    final label = _isThisSession && _controller.setupLabel.isNotEmpty
        ? _controller.setupLabel
        : AppLocalizations.of(context).meetingNotePreparing;
    final progress = _isThisSession ? _controller.setupProgress : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: widget.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress == 0 ? null : progress,
        ),
      ],
    );
  }

  Widget _buildRecording(ThemeData theme, AppLocalizations l10n) {
    final elapsed = _isThisSession ? _controller.elapsed : Duration.zero;
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final transcript = _displayTranscript;
    final transcribing = _isThisSession && _controller.transcribing;
    final systemAudio =
        _isThisSession && _controller.systemAudioCapturing;
    final stopping = _isThisSession && _controller.isStopping;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.circle, color: Colors.red, size: 10),
            const SizedBox(width: 6),
            Text(
              l10n.meetingNoteRecordingTime(mm, ss),
              style: theme.textTheme.bodySmall?.copyWith(
                color: widget.scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: widget.scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                _recordingBadgeLabel(l10n),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _recordingBadgeColor(),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (systemAudio) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: l10n.meetingNoteSystemAudioCaptured,
                child: Icon(
                  Icons.speaker_rounded,
                  size: 14,
                  color: widget.scheme.primary,
                ),
              ),
            ],
            const Spacer(),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: widget.scheme.errorContainer,
                foregroundColor: widget.scheme.onErrorContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: stopping ? null : _stopRecording,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (stopping)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.scheme.onErrorContainer,
                      ),
                    )
                  else
                    const Icon(Icons.stop_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    stopping ? l10n.meetingNoteStopping : l10n.meetingNoteStop,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 160),
          decoration: BoxDecoration(
            color: widget.scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: SingleChildScrollView(
            reverse: true,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildColoredTranscript(
                  _recordingTranscriptCaption(l10n),
                  theme.textTheme.bodySmall?.copyWith(
                    color: transcript.isEmpty || !_generateTranscription
                        ? widget.scheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : widget.scheme.onSurface,
                    height: 1.5,
                  ),
                ),
                if (transcribing && _runLocalWhisperDuringRecording)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        FolioLoadingIndicator(
                          size: FolioLoadingSize.small,
                          color: widget.scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.meetingNoteTranscribing,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: widget.scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.appSettings.isAiRuntimeEnabled && _isThisSession)
          MeetingNoteLiveAssistPanel(
            session: widget.session,
            appSettings: widget.appSettings,
            pageId: widget.page.id,
            blockId: widget.block.id,
            scheme: widget.scheme,
            initialAutoAssistEnabled:
                widget.block.meetingNoteAutoAssistEnabled == true,
          ),
      ],
    );
  }

  Widget _buildCloudProcessing(ThemeData theme, AppLocalizations l10n) {
    final total = _isThisSession ? _controller.cloudTotalChunks : 0;
    final done = _isThisSession ? _controller.cloudProcessedChunks : 0;
    final progress = total > 0 ? (done / total).clamp(0, 1) : null;
    final remaining =
        _isThisSession ? _controller.estimatedCloudRemaining() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.meetingNoteCloudProcessing,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: widget.scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_isThisSession)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: widget.scheme.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () =>
                    unawaited(_controller.cancelCloudProcessingAndAwait()),
                icon: const Icon(Icons.stop_rounded, size: 16),
                label: Text(l10n.meetingNoteCancelUpload),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress?.toDouble()),
        const SizedBox(height: 8),
        Text(
          l10n.meetingNoteCloudProcessingSubtitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: widget.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.meetingNoteCloudProgress(done, total),
          style: theme.textTheme.labelSmall?.copyWith(
            color: widget.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          remaining == null
              ? l10n.meetingNoteCloudEtaCalculating
              : l10n.meetingNoteCloudEta(_formatDurationClock(remaining)),
          style: theme.textTheme.labelSmall?.copyWith(
            color: widget.scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  IconData _bookmarkIcon(MeetingNoteBookmarkType type) => switch (type) {
    MeetingNoteBookmarkType.important => Icons.push_pin_outlined,
    MeetingNoteBookmarkType.decision => Icons.gavel_outlined,
    MeetingNoteBookmarkType.actionItem => Icons.check_circle_outline,
    MeetingNoteBookmarkType.question => Icons.help_outline,
    MeetingNoteBookmarkType.note => Icons.sticky_note_2_outlined,
  };

  String _bookmarkTypeLabel(AppLocalizations l10n, MeetingNoteBookmarkType type) =>
      switch (type) {
        MeetingNoteBookmarkType.important => l10n.meetingNoteBookmarkTypeImportant,
        MeetingNoteBookmarkType.decision => l10n.meetingNoteBookmarkTypeDecision,
        MeetingNoteBookmarkType.actionItem =>
          l10n.meetingNoteBookmarkTypeActionItem,
        MeetingNoteBookmarkType.question => l10n.meetingNoteBookmarkTypeQuestion,
        MeetingNoteBookmarkType.note => l10n.meetingNoteBookmarkTypeNote,
      };

  Widget _buildBookmarksRow(ThemeData theme, AppLocalizations l10n) {
    final bookmarks = widget.block.meetingNoteBookmarks;
    if (bookmarks == null || bookmarks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: bookmarks.map((b) {
          final label = _bookmarkTypeLabel(l10n, b.type);
          final timestamp = _formatDurationClock(
            Duration(milliseconds: b.timestampMs),
          );
          return Tooltip(
            message: b.label.isNotEmpty ? '$label — ${b.label}' : label,
            child: Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(_bookmarkIcon(b.type), size: 14),
              label: Text(
                timestamp,
                style: theme.textTheme.labelSmall,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _generateSummary() async {
    if (!await _ensureCloudOptIn()) return;
    if (!mounted) return;
    setState(() {
      _generatingSummary = true;
      _summaryError = null;
    });
    try {
      final result = await MeetingNotePreparationService.instance
          .generateSummary(
            session: widget.session,
            pageId: widget.page.id,
            blockId: widget.block.id,
          );
      if (!mounted) return;
      setState(() {
        _generatingSummary = false;
        if (result == null) {
          _summaryError = AppLocalizations.of(context).meetingNotePrepFailed;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generatingSummary = false;
        _summaryError = AppLocalizations.of(context).meetingNotePrepFailed;
      });
    }
  }

  Future<void> _materializeActionItem(int index) async {
    setState(() => _materializingActionItem.add(index));
    try {
      MeetingNotePreparationService.instance.materializeActionItem(
        session: widget.session,
        pageId: widget.page.id,
        blockId: widget.block.id,
        index: index,
      );
    } finally {
      if (mounted) {
        setState(() => _materializingActionItem.remove(index));
      }
    }
  }

  Widget _buildSummarySection(ThemeData theme, AppLocalizations l10n) {
    final summary = widget.block.meetingNoteSummary;
    if (summary == null) return const SizedBox.shrink();
    final narrative = (summary['narrative'] as String?)?.trim() ?? '';
    final keyPoints = (summary['keyPoints'] as List?)?.cast<Object?>() ?? const [];
    final actionItems =
        (summary['actionItems'] as List?)?.cast<Object?>() ?? const [];
    if (narrative.isEmpty && keyPoints.isEmpty && actionItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (narrative.isNotEmpty) ...[
              Text(
                l10n.meetingNoteSummaryTitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(narrative, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
            ],
            if (keyPoints.isNotEmpty) ...[
              Text(
                l10n.meetingNoteKeyPointsTitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              for (final p in keyPoints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $p', style: theme.textTheme.bodySmall),
                ),
              const SizedBox(height: 8),
            ],
            if (actionItems.isNotEmpty) ...[
              Text(
                l10n.meetingNoteActionItemsTitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < actionItems.length; i++)
                _buildActionItemRow(theme, l10n, i, actionItems[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionItemRow(
    ThemeData theme,
    AppLocalizations l10n,
    int index,
    Object? rawItem,
  ) {
    if (rawItem is! Map) return const SizedBox.shrink();
    final title = (rawItem['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return const SizedBox.shrink();
    final taskBlockId = rawItem['taskBlockId'] as String?;
    final materializing = _materializingActionItem.contains(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text('• $title', style: theme.textTheme.bodySmall),
          ),
          if (taskBlockId != null)
            Icon(
              Icons.check_circle_outline_rounded,
              size: 14,
              color: widget.scheme.primary,
            )
          else
            InkWell(
              onTap: materializing
                  ? null
                  : () => unawaited(_materializeActionItem(index)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: materializing
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.scheme.primary,
                        ),
                      )
                    : Text(
                        l10n.meetingNoteCreateTask,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: widget.scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsSummary(ThemeData theme, AppLocalizations l10n) {
    final raw = widget.block.meetingNoteMetricsSummary;
    if (raw == null) return const SizedBox.shrink();
    final snapshot = MeetingNoteMetricsSnapshot.fromJson(raw);
    if (snapshot.totalWords <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.query_stats_rounded,
            size: 14,
            color: widget.scheme.onSurfaceVariant,
          ),
          Text(
            l10n.meetingNoteMetricsWpm(snapshot.wordsPerMinute.round()),
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.scheme.onSurfaceVariant,
            ),
          ),
          Text(
            '·',
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.scheme.onSurfaceVariant,
            ),
          ),
          Text(
            l10n.meetingNoteMetricsQuestions(snapshot.questionCount),
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.scheme.onSurfaceVariant,
            ),
          ),
          for (final entry in snapshot.talkRatioBySpeaker.entries) ...[
            Text(
              '·',
              style: theme.textTheme.labelSmall?.copyWith(
                color: widget.scheme.onSurfaceVariant,
              ),
            ),
            Text(
              l10n.meetingNoteTalkRatioCompact(
                entry.key,
                (entry.value * 100).round(),
              ),
              style: theme.textTheme.labelSmall?.copyWith(
                color: widget.scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompleted(ThemeData theme, AppLocalizations l10n) {
    final savedPath =
        _isThisSession ? _controller.savedAudioPath : null;
    final file =
        widget.resolvedFile ??
        ((savedPath != null && savedPath.isNotEmpty) ? File(savedPath) : null);
    final transcript = _displayTranscript;
    final runtimeError = _resolveRuntimeError(l10n);
    final cloudFallback = _resolveCloudFallback(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (file != null)
          FolioAudioBlockPlayer(
            key: ValueKey(file.path),
            file: file,
            scheme: widget.scheme,
          ),
        if (file != null) const SizedBox(height: 10),
        _buildMetricsSummary(theme, l10n),
        _buildBookmarksRow(theme, l10n),
        _buildSummarySection(theme, l10n),
        if (transcript.isNotEmpty && widget.appSettings.isAiRuntimeEnabled) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: _loadingTextButton(
              loading: _generatingSummary,
              onPressed: _generateSummary,
              icon: Icons.summarize_outlined,
              label: widget.block.meetingNoteSummary != null
                  ? l10n.meetingNoteRegenerateSummary
                  : l10n.meetingNoteGenerateSummary,
            ),
          ),
          if (_summaryError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _summaryError!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: widget.scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
        if (transcript.isNotEmpty) ...[
          Text(
            l10n.meetingNoteTranscriptionTitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: widget.scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: _buildColoredTranscript(
                transcript,
                theme.textTheme.bodySmall?.copyWith(
                  color: widget.scheme.onSurface,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ] else ...[
          Text(
            widget.block.meetingNoteTranscriptionEnabled == false
                ? l10n.meetingNotePerNoteTranscriptionOffHint
                : l10n.meetingNoteNoTranscription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
        if (file != null && transcript.isEmpty) ...[
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: PostHocTranscriptionJobManager.instance,
            builder: (context, _) {
              final job = PostHocTranscriptionJobManager.instance.jobFor(
                widget.page.id,
                widget.block.id,
              );
              if (job == null) {
                return _buildPostHocTranscribeButton(l10n, file);
              }
              return ListenableBuilder(
                listenable: job,
                builder: (context, _) =>
                    _buildPostHocJobStatus(theme, l10n, job, file),
              );
            },
          ),
        ],
        if (runtimeError != null) ...[
          const SizedBox(height: 8),
          Text(
            runtimeError,
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.scheme.error,
            ),
          ),
        ],
        if (cloudFallback != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: widget.scheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  cloudFallback,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: widget.scheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_isThisSession && _controller.canRetryCloudUpload) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () =>
                  unawaited(_controller.retryCloudProcessing()),
              icon: const Icon(Icons.cloud_upload_rounded, size: 16),
              label: Text(l10n.meetingNoteRetryCloudUpload),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPostHocTranscribeButton(AppLocalizations l10n, File file) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => unawaited(_openPostHocTranscribeDialog(file)),
        icon: const Icon(Icons.subtitles_rounded, size: 16),
        label: Text(l10n.meetingNoteTranscribeNow),
      ),
    );
  }

  Widget _buildPostHocJobStatus(
    ThemeData theme,
    AppLocalizations l10n,
    PostHocTranscriptionJob job,
    File file,
  ) {
    if (job.state == PostHocTranscriptionJobState.running) {
      final isCloud = job.engine == PostHocTranscriptionEngine.quillCloud;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isCloud
                      ? l10n.meetingNoteCloudProcessing
                      : l10n.meetingNoteTranscribing,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: widget.scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isCloud)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: widget.scheme.error,
                  ),
                  onPressed: () => PostHocTranscriptionJobManager.instance
                      .cancel(widget.page.id, widget.block.id),
                  child: Text(l10n.meetingNoteCancelUpload),
                ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: isCloud && job.totalChunks > 0
                ? job.processedChunks / job.totalChunks
                : null,
          ),
          if (isCloud && job.totalChunks > 0) ...[
            const SizedBox(height: 4),
            Text(
              l10n.meetingNoteCloudProgress(
                job.processedChunks,
                job.totalChunks,
              ),
              style: theme.textTheme.labelSmall?.copyWith(
                color: widget.scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }

    if (job.state == PostHocTranscriptionJobState.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: widget.scheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  job.errorMessage?.trim().isNotEmpty == true
                      ? job.errorMessage!
                      : l10n.meetingNoteChunkTranscriptionError,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: widget.scheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildPostHocTranscribeButton(l10n, file),
        ],
      );
    }

    // cancelled: se ofrece de nuevo el botón para reintentar; done no debería
    // llegar aquí (transcript ya deja de estar vacío en el siguiente build).
    return _buildPostHocTranscribeButton(l10n, file);
  }

  Future<void> _openPostHocTranscribeDialog(File file) {
    return showPostHocTranscribeDialog(
      context: context,
      session: widget.session,
      appSettings: widget.appSettings,
      page: widget.page,
      block: widget.block,
      audioFile: file,
      entitlements: widget.folioCloudEntitlements,
    );
  }
}

class _MeetingLanguageOption {
  const _MeetingLanguageOption({required this.code, required this.labelKey});

  final String code;
  final String labelKey;
}
