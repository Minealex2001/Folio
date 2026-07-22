import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../app/widgets/folio_skeletons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/block.dart';
import '../../../models/folio_page.dart';
import '../../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../../services/meeting_note_session_controller.dart';
import '../../../services/system_audio_service.dart';
import '../../../services/transcription_hardware_profile.dart';
import '../../../services/whisper_service.dart';
import '../../../session/vault_session.dart';
import 'folio_special_block_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return switch (_effectiveState) {
      MeetingNoteSessionState.idle => _buildIdle(theme, l10n),
      MeetingNoteSessionState.setup => _buildSetup(theme),
      MeetingNoteSessionState.recording => _buildRecording(theme, l10n),
      MeetingNoteSessionState.cloudProcessing =>
        _buildCloudProcessing(theme, l10n),
      MeetingNoteSessionState.completed => _buildCompleted(theme, l10n),
    };
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
              onPressed: _stopRecording,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stop_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(l10n.meetingNoteStop),
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
                SelectableText(
                  _recordingTranscriptCaption(l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
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
        Text(
          l10n.meetingNoteCloudProcessing,
          style: theme.textTheme.bodySmall?.copyWith(
            color: widget.scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
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
        if (file != null) FolioAudioBlockPlayer(file: file, scheme: widget.scheme),
        if (file != null) const SizedBox(height: 10),
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
              child: SelectableText(
                transcript,
                style: theme.textTheme.bodySmall?.copyWith(
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
      ],
    );
  }
}

class _MeetingLanguageOption {
  const _MeetingLanguageOption({required this.code, required this.labelKey});

  final String code;
  final String labelKey;
}
