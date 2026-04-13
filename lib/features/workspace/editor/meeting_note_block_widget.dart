import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../app/app_settings.dart';
import '../../../data/vault_paths.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/block.dart';
import '../../../models/folio_page.dart';
import '../../../services/audio_mixer_service.dart';
import '../../../services/diarization_service.dart';
import '../../../services/folio_cloud/folio_cloud_callable.dart';
import '../../../services/folio_cloud/folio_cloud_entitlements.dart';
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

enum _MeetingState { idle, setup, recording, cloudProcessing, completed }

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

  _MeetingState _state = _MeetingState.idle;

  String _setupLabel = '';
  double _setupProgress = 0;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  String _transcript = '';
  bool _transcribing = false;
  String _selectedLanguageCode = 'auto';
  bool _languageInitialized = false;
  String? _diarizationSessionId;
  StreamSubscription<File>? _chunkSub;

  String? _savedAudioPath;
  String? _runtimeError;

  _TranscriptionProvider _provider = _TranscriptionProvider.local;
  String? _cloudFallbackNotice;
  final List<File> _pendingCloudChunks = [];
  int _cloudTotalChunks = 0;
  int _cloudProcessedChunks = 0;
  DateTime? _cloudProcessingStartedAt;
  Timer? _cloudEtaTicker;

  late TranscriptionHardwareSnapshot _hardwareSnapshot;
  bool _generateTranscription = true;

  @override
  void initState() {
    super.initState();
    _hardwareSnapshot = TranscriptionHardwareProfile.loadCached();
    _generateTranscription = widget.block.meetingNoteTranscriptionEnabled != false;
    _loadProviderFromBlock();
    _normalizeMeetingNoteProviderWithAi();
    if (widget.resolvedFile != null) {
      _state = _MeetingState.completed;
      _transcript = widget.block.text;
      _savedAudioPath = widget.resolvedFile!.path;
    }
  }

  @override
  void didUpdateWidget(MeetingNoteBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resolvedFile != null &&
        widget.resolvedFile?.path != oldWidget.resolvedFile?.path) {
      _state = _MeetingState.completed;
      _transcript = widget.block.text;
      _savedAudioPath = widget.resolvedFile!.path;
    }
    if (oldWidget.appSettings.isAiRuntimeEnabled !=
            widget.appSettings.isAiRuntimeEnabled ||
        oldWidget.block.meetingNoteProvider != widget.block.meetingNoteProvider) {
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
    _timer?.cancel();
    _cloudEtaTicker?.cancel();
    _chunkSub?.cancel();
    final sid = _diarizationSessionId;
    if (sid != null) {
      DiarizationService.instance.endSession(sid);
    }
    _cleanupPendingChunks();
    super.dispose();
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

  String? _whisperLanguageArg() {
    final code = _selectedLanguageCode.trim();
    if (code.isEmpty || code == 'auto') return null;
    return code;
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

  String _recordingTranscriptCaption(AppLocalizations l10n) {
    if (!_generateTranscription) {
      return l10n.meetingNotePerNoteTranscriptionOffHint;
    }
    if (_transcript.isEmpty) return l10n.meetingNoteWaitingTranscription;
    return _transcript;
  }

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context);
    _hardwareSnapshot = TranscriptionHardwareProfile.loadCached();
    setState(() {
      _state = _MeetingState.setup;
      _setupLabel = l10n.meetingNotePreparing;
      _setupProgress = 0;
      _runtimeError = null;
      _cloudFallbackNotice = null;
    });

    if (_runLocalWhisperDuringRecording) {
      try {
        await WhisperService.instance.ensureReady(
          modelId: _activeModelId(),
          onProgress: (label, prog) {
            if (!mounted) return;
            setState(() {
              _setupLabel = label;
              _setupProgress = prog;
            });
          },
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _state = _MeetingState.idle;
          _runtimeError = l10n.meetingNoteWhisperInitError(e.toString());
        });
        return;
      }
    } else if (mounted) {
      setState(() {
        _setupLabel = l10n.meetingNotePreparing;
        _setupProgress = 1;
      });
    }

    if (!mounted) return;

    final micDeviceId = widget.appSettings.meetingNoteMicDeviceId.trim();
    final systemDeviceId = widget.appSettings.meetingNoteSystemDeviceId.trim();
    final ok = await AudioMixerService.instance.start(
      micDeviceId: micDeviceId.isEmpty ? null : micDeviceId,
      systemOutputDeviceId: systemDeviceId.isEmpty ? null : systemDeviceId,
    );
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _state = _MeetingState.idle;
        _runtimeError = l10n.meetingNoteAudioAccessError;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.meetingNoteMicrophoneAccessError)),
      );
      return;
    }

    if (_runLocalWhisperDuringRecording) {
      final sid = const Uuid().v4();
      _diarizationSessionId = sid;
      DiarizationService.instance.startSession(sid);
    }
    _chunkSub = AudioMixerService.instance.chunkStream.listen(_onChunk);

    _pendingCloudChunks.clear();
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });

    setState(() {
      _state = _MeetingState.recording;
      _transcript = '';
      _transcribing = false;
      _cloudTotalChunks = 0;
      _cloudProcessedChunks = 0;
    });
  }

  Future<void> _onChunk(File chunkFile) async {
    if (!mounted) return;

    final saveForCloud = _effectiveCloudPostProcess;
    final runLocal = _runLocalWhisperDuringRecording;

    if (!runLocal && !saveForCloud) {
      unawaited(chunkFile.delete().catchError((_) => File('')));
      return;
    }

    if (runLocal) {
      if (mounted) setState(() => _transcribing = true);
    }

    if (saveForCloud) {
      _pendingCloudChunks.add(chunkFile);
    }

    if (runLocal) {
      final chunkText = await _onChunkLocal(
        chunkFile,
        deleteAfter: !saveForCloud,
      );

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (chunkText.isNotEmpty) {
        setState(() {
          _transcript = _mergeTranscriptChunk(_transcript, chunkText);
          _runtimeError = null;
        });
      } else {
        setState(() {
          _runtimeError =
              WhisperService.instance.lastError ??
              l10n.meetingNoteChunkTranscriptionError;
        });
      }
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<String> _onChunkLocal(
    File chunkFile, {
    bool deleteAfter = true,
  }) async {
    final text = await WhisperService.instance.transcribe(
      chunkFile,
      language: _whisperLanguageArg(),
      modelId: _activeModelId(),
    );

    String finalText = text;
    if (text.isNotEmpty) {
      final sid = _diarizationSessionId;
      final diarized = await DiarizationService.instance.diarizeChunk(
        audioChunk: chunkFile,
        transcript: text,
        language: _whisperLanguageArg() ?? 'auto',
        sessionId: sid ?? 'meeting-${widget.page.id}-${widget.block.id}',
      );
      if (diarized != null && diarized.trim().isNotEmpty) {
        finalText = diarized.trim();
      }
    }

    if (deleteAfter) {
      unawaited(chunkFile.delete().catchError((_) => File('')));
    }
    return finalText;
  }

  Future<void> _processCloudChunks() async {
    final l10n = AppLocalizations.of(context);
    final chunks = List<File>.from(_pendingCloudChunks);
    _pendingCloudChunks.clear();

    final inkCostTotal = math.max(1, (_elapsed.inSeconds / 300).ceil());
    String cloudTranscript = '';
    var cloudFailed = false;

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];

      if (!mounted) return;
      setState(() => _cloudProcessedChunks = i + 1);

      try {
        final bytes = await chunk.readAsBytes();
        final payload = <String, dynamic>{
          'audioBase64': _base64Encode(bytes),
          'language': _whisperLanguageArg() ?? 'auto',
          'chargeInk': i == 0,
          if (i == 0) 'inkAmount': inkCostTotal,
        };

        final res = await callFolioHttpsCallable(
          'folioCloudTranscribeChunk',
          payload,
        );

        final inkRaw = res is Map ? res['ink'] : null;
        if (inkRaw is Map) {
          final ent = widget.folioCloudEntitlements;
          final monthly = (inkRaw['monthlyBalance'] as num?)?.toInt();
          final purchased = (inkRaw['purchasedBalance'] as num?)?.toInt();
          if (ent != null &&
              monthly != null &&
              purchased != null &&
              monthly >= 0 &&
              purchased >= 0) {
            ent.applyInkBalancesFromCloudAi(
              monthlyBalance: monthly,
              purchasedBalance: purchased,
            );
          }
        }

        final text = res is Map ? '${res['transcript'] ?? ''}' : '';
        if (text.isNotEmpty) {
          cloudTranscript = cloudTranscript.isEmpty
              ? text
              : _mergeTranscriptChunk(cloudTranscript, text);
        }
      } on FirebaseFunctionsException catch (e) {
        setState(() {
          _cloudFallbackNotice = e.code == 'resource-exhausted'
              ? l10n.meetingNoteCloudInkExhaustedNotice
              : l10n.meetingNoteCloudFallbackNotice;
        });
        cloudFailed = true;
        break;
      } catch (_) {
        setState(() {
          _cloudFallbackNotice = l10n.meetingNoteCloudFallbackNotice;
        });
        cloudFailed = true;
        break;
      } finally {
        unawaited(chunk.delete().catchError((_) => File('')));
      }
    }

    for (final chunk in chunks) {
      if (await chunk.exists()) {
        unawaited(chunk.delete().catchError((_) => File('')));
      }
    }

    if (!mounted) return;
    if (!cloudFailed && cloudTranscript.isNotEmpty) {
      setState(() => _transcript = cloudTranscript);
      widget.session.updateBlockText(
        widget.page.id,
        widget.block.id,
        cloudTranscript,
      );
    }

    _cloudEtaTicker?.cancel();
    _cloudEtaTicker = null;
    _cloudProcessingStartedAt = null;
    setState(() => _state = _MeetingState.completed);
  }

  Duration? _estimatedCloudRemaining() {
    final startedAt = _cloudProcessingStartedAt;
    if (startedAt == null) return null;
    if (_cloudTotalChunks <= 0) return null;
    if (_cloudProcessedChunks <= 0) return null;

    final elapsed = DateTime.now().difference(startedAt);
    final perChunkMs = elapsed.inMilliseconds / _cloudProcessedChunks;
    final remainingChunks = _cloudTotalChunks - _cloudProcessedChunks;
    if (remainingChunks <= 0) return Duration.zero;

    final remainingMs = (perChunkMs * remainingChunks).round();
    if (remainingMs < 0) return Duration.zero;
    return Duration(milliseconds: remainingMs);
  }

  String _formatDurationClock(Duration d) {
    final totalSeconds = d.inSeconds.clamp(0, 359999);
    final mm = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _cleanupPendingChunks() {
    for (final chunk in _pendingCloudChunks) {
      unawaited(chunk.delete().catchError((_) => File('')));
    }
    _pendingCloudChunks.clear();
  }

  static String _base64Encode(List<int> bytes) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buf = StringBuffer();
    var i = 0;
    while (i + 2 < bytes.length) {
      final b0 = bytes[i];
      final b1 = bytes[i + 1];
      final b2 = bytes[i + 2];
      buf
        ..writeCharCode(chars.codeUnitAt((b0 >> 2) & 63))
        ..writeCharCode(chars.codeUnitAt(((b0 & 3) << 4) | ((b1 >> 4) & 15)))
        ..writeCharCode(chars.codeUnitAt(((b1 & 15) << 2) | ((b2 >> 6) & 3)))
        ..writeCharCode(chars.codeUnitAt(b2 & 63));
      i += 3;
    }
    if (i < bytes.length) {
      final b0 = bytes[i];
      if (i + 1 < bytes.length) {
        final b1 = bytes[i + 1];
        buf
          ..writeCharCode(chars.codeUnitAt((b0 >> 2) & 63))
          ..writeCharCode(chars.codeUnitAt(((b0 & 3) << 4) | ((b1 >> 4) & 15)))
          ..writeCharCode(chars.codeUnitAt((b1 & 15) << 2))
          ..write('=');
      } else {
        buf
          ..writeCharCode(chars.codeUnitAt((b0 >> 2) & 63))
          ..writeCharCode(chars.codeUnitAt((b0 & 3) << 4))
          ..write('==');
      }
    }
    return buf.toString();
  }

  String _mergeTranscriptChunk(String current, String incoming) {
    final base = current.trimRight();
    final add = incoming.trim();
    if (add.isEmpty) return current;
    if (base.isEmpty) return add;

    final baseLines = base
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final addLines = add.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (baseLines.isEmpty) return add;
    if (addLines.isEmpty) return base;

    var consumedFirstIncoming = false;
    final lastIndex = baseLines.length - 1;
    final lastLine = baseLines[lastIndex];
    final firstIncoming = addLines.first;

    final parsedLast = _parseSpeakerLine(lastLine);
    final parsedFirst = _parseSpeakerLine(firstIncoming);

    if (parsedLast != null && parsedFirst != null) {
      if (parsedLast.speakerId == parsedFirst.speakerId &&
          _shouldContinueParagraph(parsedLast.text, parsedFirst.text)) {
        baseLines[lastIndex] =
            'Speaker ${parsedLast.speakerId}: ${_joinSegments(parsedLast.text, parsedFirst.text)}';
        consumedFirstIncoming = true;
      }
    } else if (parsedLast == null && parsedFirst == null) {
      if (_shouldContinueParagraph(lastLine, firstIncoming)) {
        baseLines[lastIndex] = _joinSegments(lastLine, firstIncoming);
        consumedFirstIncoming = true;
      }
    }

    final remainingIncoming = consumedFirstIncoming
        ? addLines.skip(1).toList()
        : addLines;
    if (remainingIncoming.isNotEmpty) baseLines.addAll(remainingIncoming);
    return baseLines.join('\n');
  }

  _SpeakerLine? _parseSpeakerLine(String line) {
    final m = RegExp(r'^\s*Speaker\s+(\d+)\s*:\s*(.+?)\s*$').firstMatch(line);
    if (m == null) return null;
    final speakerId = int.tryParse(m.group(1) ?? '');
    final text = (m.group(2) ?? '').trim();
    if (speakerId == null || text.isEmpty) return null;
    return _SpeakerLine(speakerId: speakerId, text: text);
  }

  bool _shouldContinueParagraph(String previousText, String nextText) {
    final prev = previousText.trimRight();
    final next = nextText.trimLeft();
    if (prev.isEmpty || next.isEmpty) return false;

    final hardStop = RegExp(r'[\.!\?…]["”’\)\]]*$').hasMatch(prev);
    if (!hardStop) return true;

    if (RegExp(r'^[,.;:\)\]]').hasMatch(next)) return true;
    if (RegExp(r'^[a-z]').hasMatch(next)) return true;
    if (RegExp(
      r'^(y|e|o|u|de|que|pero|pues|entonces|and|but|or|so|because|then)\b',
      caseSensitive: false,
    ).hasMatch(next)) {
      return true;
    }
    return false;
  }

  String _joinSegments(String left, String right) {
    final a = left.trimRight();
    final b = right.trimLeft();
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;

    if (a.endsWith('-')) return '$a$b';
    if (RegExp(r'^[,.;:!?\)]').hasMatch(b)) return '$a$b';
    return '$a $b';
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _timer = null;
    await _chunkSub?.cancel();
    _chunkSub = null;

    final sid = _diarizationSessionId;
    if (sid != null) {
      DiarizationService.instance.endSession(sid);
      _diarizationSessionId = null;
    }

    const uuid = Uuid();
    final dateStr = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(':', '-');
    final filename = 'meeting_${dateStr}_${uuid.v4()}.wav';

    final attachDir = await VaultPaths.attachmentsDirectory();
    final destPath = p.join(attachDir.path, filename);
    final wavFile = await AudioMixerService.instance.stop(destPath: destPath);

    if (!mounted) return;

    if (wavFile == null) {
      _cleanupPendingChunks();
      setState(() => _state = _MeetingState.idle);
      return;
    }

    final vault = await VaultPaths.vaultDirectory();
    final relative = p
        .relative(wavFile.path, from: vault.path)
        .replaceAll(r'\\', '/');

    widget.session.updateBlockUrl(widget.page.id, widget.block.id, relative);
    widget.session.updateBlockText(
      widget.page.id,
      widget.block.id,
      _transcript,
    );
    _savedAudioPath = wavFile.path;

    final shouldPostProcessCloud =
        _effectiveCloudPostProcess && _pendingCloudChunks.isNotEmpty;

    if (shouldPostProcessCloud) {
      setState(() {
        _state = _MeetingState.cloudProcessing;
        _cloudTotalChunks = _pendingCloudChunks.length;
        _cloudProcessedChunks = 0;
        _cloudProcessingStartedAt = DateTime.now();
      });
      _cloudEtaTicker?.cancel();
      _cloudEtaTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _state == _MeetingState.cloudProcessing) {
          setState(() {});
        }
      });
      await _processCloudChunks();
    } else {
      _cleanupPendingChunks();
      setState(() => _state = _MeetingState.completed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return switch (_state) {
      _MeetingState.idle => _buildIdle(theme, l10n),
      _MeetingState.setup => _buildSetup(theme),
      _MeetingState.recording => _buildRecording(theme, l10n),
      _MeetingState.cloudProcessing => _buildCloudProcessing(theme, l10n),
      _MeetingState.completed => _buildCompleted(theme, l10n),
    };
  }

  Widget _buildIdle(ThemeData theme, AppLocalizations l10n) {
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
        if (_runtimeError != null) ...[
          const SizedBox(height: 8),
          Text(
            _runtimeError!,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _setupLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: widget.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _setupProgress == 0 ? null : _setupProgress,
        ),
      ],
    );
  }

  Widget _buildRecording(ThemeData theme, AppLocalizations l10n) {
    final mm = _elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');

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
            if (SystemAudioService.instance.isCapturing) ...[
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
                    color: _transcript.isEmpty || !_generateTranscription
                        ? widget.scheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : widget.scheme.onSurface,
                    height: 1.5,
                  ),
                ),
                if (_transcribing && _runLocalWhisperDuringRecording)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: widget.scheme.primary,
                          ),
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
    final progress = _cloudTotalChunks > 0
        ? (_cloudProcessedChunks / _cloudTotalChunks).clamp(0, 1)
        : null;
    final remaining = _estimatedCloudRemaining();

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
          l10n.meetingNoteCloudProgress(
            _cloudProcessedChunks,
            _cloudTotalChunks,
          ),
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
    final file =
        widget.resolvedFile ??
        ((_savedAudioPath != null && _savedAudioPath!.isNotEmpty)
            ? File(_savedAudioPath!)
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (file != null) _buildPlayer(theme, file),
        if (file != null) const SizedBox(height: 10),
        if (_transcript.isNotEmpty) ...[
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
                _transcript,
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
        if (_runtimeError != null) ...[
          const SizedBox(height: 8),
          Text(
            _runtimeError!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.scheme.error,
            ),
          ),
        ],
        if (_cloudFallbackNotice != null) ...[
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
                  _cloudFallbackNotice!,
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

  Widget _buildPlayer(ThemeData theme, File file) {
    return FolioAudioBlockPlayer(file: file, scheme: widget.scheme);
  }
}

class _MeetingLanguageOption {
  const _MeetingLanguageOption({required this.code, required this.labelKey});

  final String code;
  final String labelKey;
}

class _SpeakerLine {
  const _SpeakerLine({required this.speakerId, required this.text});

  final int speakerId;
  final String text;
}
