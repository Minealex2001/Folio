import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../app/app_settings.dart';
import '../data/vault_paths.dart';
import '../meeting_worker/meeting_worker_host.dart';
import '../meeting_worker/meeting_worker_protocol.dart';
import '../session/vault_session.dart';
import 'app_logger.dart';
import 'folio_cloud/cloud_transcription_chunk_uploader.dart';
import 'folio_cloud/folio_cloud_entitlements.dart';
import 'meeting_note_metrics_service.dart';
import 'meeting_note_transcript_merge.dart';
import 'system_audio_service.dart';

import '../services/folio_cloud/folio_cloud_exception.dart';
enum MeetingNoteSessionState {
  idle,
  setup,
  recording,
  cloudProcessing,
  completed,
}

/// Cliente en Folio del pipeline de reunión (proceso worker aparte).
class MeetingNoteSessionController extends ChangeNotifier {
  MeetingNoteSessionController._();
  static final MeetingNoteSessionController instance =
      MeetingNoteSessionController._();

  MeetingNoteSessionState _state = MeetingNoteSessionState.idle;
  String? _pageId;
  String? _blockId;
  String _setupLabel = '';
  double _setupProgress = 0;
  Duration _elapsed = Duration.zero;
  String _transcript = '';
  bool _transcribing = false;
  bool _systemAudioCapturing = false;
  String? _runtimeErrorCode;
  String? _runtimeErrorDetail;
  String? _cloudFallbackNoticeCode;
  String? _savedAudioPath;
  bool _runLocalWhisper = false;
  bool _saveCloudChunks = false;
  bool _generateTranscription = true;
  String _languageCode = 'auto';
  String _modelId = 'tiny';
  String _provider = 'local';

  final List<File> _pendingCloudChunks = [];
  int _cloudTotalChunks = 0;
  int _cloudProcessedChunks = 0;
  DateTime? _cloudProcessingStartedAt;
  Future<void>? _cloudProcessingFuture;
  bool _cloudCancelRequested = false;
  bool _cloudInkChargeSent = false;
  String _cloudTranscriptAccum = '';

  static const _cloudProcessingMaxDuration = Duration(minutes: 8);
  static const _cloudChunkMaxAttempts = 3;
  static const _cloudChunkNoRetryCodes = {
    'resource-exhausted',
    'unauthenticated',
    'permission-denied',
  };
  static const _cloudJobPollMaxWait = Duration(minutes: 4);

  // Mutables (con valores de producción por defecto) solo para poder
  // acelerar los backoffs/polling en tests sin esperas reales de segundos.
  static List<Duration> _cloudChunkRetryDelays = const [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];
  static Duration _cloudJobPollInterval = const Duration(seconds: 3);

  @visibleForTesting
  static set debugCloudChunkRetryDelays(List<Duration> delays) =>
      _cloudChunkRetryDelays = delays;

  @visibleForTesting
  static set debugCloudJobPollInterval(Duration interval) =>
      _cloudJobPollInterval = interval;

  ServerSocket? _server;
  Socket? _client;
  Process? _workerProcess;
  StreamSubscription<List<int>>? _clientSub;
  StreamSubscription<String>? _workerStderrSub;
  final _lineBuffer = StringBuffer();
  Completer<void>? _readyCompleter;
  Completer<Map<String, dynamic>>? _stoppedCompleter;
  bool _workerShutdownExpected = false;
  final StringBuffer _workerStderr = StringBuffer();
  bool _inProcessMode = false;

  VaultSession? _session;
  AppSettings? _appSettings;
  FolioCloudEntitlementsController? _entitlements;
  Timer? _cloudEtaTicker;

  MeetingNoteSessionState get state => _state;
  String? get pageId => _pageId;
  String? get blockId => _blockId;
  String get setupLabel => _setupLabel;
  double get setupProgress => _setupProgress;
  Duration get elapsed => _elapsed;
  String get transcript => _transcript;
  bool get transcribing => _transcribing;
  bool get systemAudioCapturing => _systemAudioCapturing;
  String? get runtimeErrorCode => _runtimeErrorCode;
  String? get runtimeErrorDetail => _runtimeErrorDetail;
  String? get cloudFallbackNoticeCode => _cloudFallbackNoticeCode;
  String? get savedAudioPath => _savedAudioPath;
  bool get runLocalWhisper => _runLocalWhisper;
  bool get saveCloudChunks => _saveCloudChunks;
  bool get generateTranscription => _generateTranscription;
  String get languageCode => _languageCode;
  String get modelId => _modelId;
  String get provider => _provider;
  int get cloudTotalChunks => _cloudTotalChunks;
  int get cloudProcessedChunks => _cloudProcessedChunks;
  DateTime? get cloudProcessingStartedAt => _cloudProcessingStartedAt;

  MeetingNoteMetricsSnapshot? _cachedMetricsSnapshot;
  String? _cachedMetricsTranscript;

  /// Fase 8: métricas de conversación en vivo, calculadas bajo demanda
  /// (cálculo puro, sin estado propio) a partir del transcript acumulado y
  /// el tiempo transcurrido. Reactivo vía `notifyListeners()` en cada
  /// transcript-delta/tick de elapsed, igual que [transcript]/[elapsed].
  ///
  /// Fase 22 (rendimiento): la UI (barra activa + panel de Live Assist) lee
  /// este getter en cada rebuild, que en grabación ocurre ~1 vez/segundo
  /// por el tick de `elapsed` — sin cache, eso reprocesaba el transcript
  /// completo (todas las líneas/palabras acumuladas) cada segundo durante
  /// toda una reunión larga. Los deltas de transcript llegan por chunk
  /// (~cada 15s), así que memoizar por identidad de `_transcript` (String
  /// inmutable en Dart) evita ~14 de cada 15 recomputaciones — el único
  /// coste es que el WPM mostrado puede quedar hasta ~15s por detrás del
  /// tiempo transcurrido real entre chunks, imperceptible para un
  /// indicador "en vivo".
  MeetingNoteMetricsSnapshot get metricsSnapshot {
    final cached = _cachedMetricsSnapshot;
    if (cached != null && _cachedMetricsTranscript == _transcript) {
      return cached;
    }
    final snapshot = MeetingMetricsService.instance.computeSnapshot(
      transcript: _transcript,
      elapsed: _elapsed,
    );
    _cachedMetricsSnapshot = snapshot;
    _cachedMetricsTranscript = _transcript;
    return snapshot;
  }

  DateTime? _lastMonologueNudgeAt;

  /// Fase 10: código del nudge activo (p. ej. `'monologue_long'`) o `null`
  /// si no aplica ninguno ahora mismo. Llamar solo mientras `state ==
  /// recording`; consulta y actualiza el rate-limit internamente cada vez
  /// que se llama, así que no debe invocarse más de una vez por rebuild.
  String? consumeActiveNudge() {
    final nudge = MeetingMetricsService.instance.checkMonologueNudge(
      snapshot: metricsSnapshot,
      lastNudgeAt: _lastMonologueNudgeAt,
      now: DateTime.now(),
    );
    if (nudge != null) {
      _lastMonologueNudgeAt = DateTime.now();
    }
    return nudge;
  }

  /// Hay fragmentos de audio sin transcribir en la nube que sobrevivieron a
  /// un fallo previo (no se borran hasta subirse con éxito) y se pueden
  /// reintentar.
  bool get canRetryCloudUpload =>
      _state == MeetingNoteSessionState.completed &&
      _pendingCloudChunks.isNotEmpty;

  bool get isActive =>
      _state == MeetingNoteSessionState.setup ||
      _state == MeetingNoteSessionState.recording ||
      _state == MeetingNoteSessionState.cloudProcessing;

  bool isSessionFor(String pageId, String blockId) =>
      _pageId == pageId && _blockId == blockId;

  bool get isAwayFromActivePage {
    if (!isActive || _pageId == null || _session == null) return false;
    return _session!.selectedPageId != _pageId;
  }

  static bool get isProcessIsolationSupported =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
      SystemAudioService.isSupported;

  Future<void> start({
    required VaultSession session,
    required AppSettings appSettings,
    required String pageId,
    required String blockId,
    required bool generateTranscription,
    required String languageCode,
    required String provider,
    required bool runLocalWhisper,
    required bool saveCloudChunks,
    required String modelId,
    FolioCloudEntitlementsController? entitlements,
  }) async {
    if (isActive) {
      if (isSessionFor(pageId, blockId)) return;
      await stop();
    }

    _session = session;
    _appSettings = appSettings;
    _entitlements = entitlements;
    _pageId = pageId;
    _blockId = blockId;
    _generateTranscription = generateTranscription;
    _languageCode = languageCode;
    _provider = provider;
    _runLocalWhisper = runLocalWhisper;
    _saveCloudChunks = saveCloudChunks;
    _modelId = modelId;
    _transcript = '';
    _elapsed = Duration.zero;
    _transcribing = false;
    _systemAudioCapturing = false;
    _runtimeErrorCode = null;
    _runtimeErrorDetail = null;
    _cloudFallbackNoticeCode = null;
    _savedAudioPath = null;
    _pendingCloudChunks.clear();
    _cloudInkChargeSent = false;
    _cloudTranscriptAccum = '';
    _lastMonologueNudgeAt = null;
    _cachedMetricsSnapshot = null;
    _cachedMetricsTranscript = null;
    _setupLabel = '';
    _setupProgress = 0;
    _state = MeetingNoteSessionState.setup;
    notifyListeners();

    if (!isProcessIsolationSupported) {
      _failIdle('audio_access', null);
      return;
    }

    try {
      await _ensureWorkerConnected();
      _send({
        'type': MeetingWorkerCmd.start,
        'micDeviceId': appSettings.meetingNoteMicDeviceId.trim(),
        'systemDeviceId': appSettings.meetingNoteSystemDeviceId.trim(),
        'modelId': modelId,
        'language': languageCode,
        'runLocalWhisper': runLocalWhisper,
        'saveCloudChunks': saveCloudChunks,
        'sessionId': const Uuid().v4(),
      });
    } catch (e) {
      AppLogger.warn(
        'External meeting worker failed; falling back in-process',
        tag: 'meeting',
        context: {'error': '$e'},
      );
      await _teardownWorker();
      try {
        await _ensureInProcessWorkerConnected();
        _send({
          'type': MeetingWorkerCmd.start,
          'micDeviceId': appSettings.meetingNoteMicDeviceId.trim(),
          'systemDeviceId': appSettings.meetingNoteSystemDeviceId.trim(),
          'modelId': modelId,
          'language': languageCode,
          'runLocalWhisper': runLocalWhisper,
          'saveCloudChunks': saveCloudChunks,
          'sessionId': const Uuid().v4(),
        });
      } catch (e2) {
        await _teardownWorker();
        _failIdle('worker_start', '$e2');
      }
    }
  }

  /// Si no es `null`, ya hay una llamada a [stop] en curso — usado tanto
  /// para exponer [isStopping] a la UI como para que una segunda llamada
  /// concurrente (p.ej. doble tap en "Detener", o `lock()` corriendo a la
  /// vez que el usuario pulsa Detener) espere el MISMO resultado en vez de
  /// mandar un segundo comando `stop` al worker. Antes de este guard, una
  /// segunda llamada sobrescribía `_stoppedCompleter`, dejando huérfano el
  /// completer de la primera (que quedaba colgada hasta su propio timeout)
  /// y el worker recibía dos comandos `stop` casi simultáneos que podían
  /// llamar dos veces a `AudioMixerService.instance.stop()` en paralelo.
  Future<void>? _stopFuture;

  bool get isStopping => _stopFuture != null;

  Future<void> stop({
    Duration stopTimeout = const Duration(seconds: 45),
    bool fast = false,
    bool startCloudProcessing = true,
  }) {
    if (_state == MeetingNoteSessionState.idle ||
        _state == MeetingNoteSessionState.completed) {
      return Future<void>.value();
    }
    if (_state == MeetingNoteSessionState.cloudProcessing) {
      return Future<void>.value();
    }
    final inFlight = _stopFuture;
    if (inFlight != null) return inFlight;

    final future = _stopImpl(
      stopTimeout: stopTimeout,
      fast: fast,
      startCloudProcessing: startCloudProcessing,
    );
    _stopFuture = future;
    return future.whenComplete(() => _stopFuture = null);
  }

  Future<void> _stopImpl({
    required Duration stopTimeout,
    required bool fast,
    required bool startCloudProcessing,
  }) async {
    final pageId = _pageId;
    final blockId = _blockId;
    final session = _session;
    if (pageId == null || blockId == null || session == null) {
      await _teardownWorker();
      _resetToIdle();
      return;
    }

    try {
      final attachDir = await VaultPaths.attachmentsDirectory();
      final dateStr = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(':', '-');
      final filename = 'meeting_${dateStr}_${const Uuid().v4()}.wav';
      final destPath = p.join(attachDir.path, filename);

      _stoppedCompleter = Completer<Map<String, dynamic>>();
      _send({
        'type': MeetingWorkerCmd.stop,
        'destPath': destPath,
        if (fast) 'fast': true,
      });

      final stopped = await _stoppedCompleter!.future.timeout(
        stopTimeout,
        onTimeout: () => <String, dynamic>{},
      );

      final wavPath = '${stopped['wavPath'] ?? ''}'.trim();
      final transcript = '${stopped['transcript'] ?? _transcript}';
      _transcript = transcript;

      if (wavPath.isEmpty) {
        _cleanupPendingChunks();
        await _teardownWorker();
        _resetToIdle();
        return;
      }

      final vault = await VaultPaths.vaultDirectory();
      final relative = p
          .relative(wavPath, from: vault.path)
          .replaceAll('\\', '/');

      session.updateBlockUrl(pageId, blockId, relative);
      session.updateBlockText(pageId, blockId, _transcript);
      final channelMeta = stopped['channelMeta'];
      if (channelMeta is Map) {
        session.updateBlockMeetingNoteChannelMeta(
          pageId,
          blockId,
          Map<String, Object?>.from(channelMeta),
        );
      }
      if (_transcript.trim().isNotEmpty) {
        session.updateBlockMeetingNoteMetricsSummary(
          pageId,
          blockId,
          metricsSnapshot.toJson(),
        );
      }
      _savedAudioPath = wavPath;

      final shouldCloud = startCloudProcessing &&
          _saveCloudChunks &&
          _pendingCloudChunks.isNotEmpty;
      try {
        _send({'type': MeetingWorkerCmd.shutdown});
      } catch (_) {}
      await _teardownWorker();

      if (shouldCloud) {
        await _runCloudProcessing();
      } else {
        _cleanupPendingChunks();
        _state = MeetingNoteSessionState.completed;
        notifyListeners();
      }
    } catch (e) {
      _runtimeErrorCode = 'stop_failed';
      _runtimeErrorDetail = '$e';
      await _teardownWorker();
      _resetToIdle();
    }
  }

  Future<void> _runCloudProcessing() async {
    _state = MeetingNoteSessionState.cloudProcessing;
    _cloudTotalChunks = _pendingCloudChunks.length;
    _cloudProcessedChunks = 0;
    _cloudProcessingStartedAt = DateTime.now();
    notifyListeners();
    _cloudEtaTicker?.cancel();
    _cloudEtaTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == MeetingNoteSessionState.cloudProcessing) {
        notifyListeners();
      }
    });
    _cloudProcessingFuture = _processCloudChunks();
    await _cloudProcessingFuture;
    _cloudProcessingFuture = null;
  }

  /// Reintenta subir/transcribir los fragmentos que sobrevivieron a un fallo
  /// previo (ver Bug de borrado destructivo en `_processCloudChunks()`).
  Future<void> retryCloudProcessing() async {
    if (!canRetryCloudUpload) return;
    _cloudFallbackNoticeCode = null;
    _runtimeErrorCode = null;
    await _runCloudProcessing();
  }

  /// Solo para tests: arranca el procesamiento en la nube directamente sobre
  /// unos fragmentos ya "grabados", sin pasar por `start()`/el proceso
  /// worker real (no es viable en `flutter test`). Combinar con
  /// [debugCallFolioHttpsCallableOverride] para simular las respuestas HTTP.
  @visibleForTesting
  Future<void> debugStartCloudProcessingForTest({
    required VaultSession session,
    required String pageId,
    required String blockId,
    required List<File> chunkFiles,
  }) async {
    _session = session;
    _pageId = pageId;
    _blockId = blockId;
    _saveCloudChunks = true;
    _elapsed = const Duration(minutes: 1);
    _pendingCloudChunks
      ..clear()
      ..addAll(chunkFiles);
    await _runCloudProcessing();
  }

  /// Solo para tests: fuerza el estado `recording` para (pageId, blockId)
  /// sin arrancar el worker real (no es viable en `flutter test`) — útil
  /// para probar UI que reacciona a `MeetingNoteSessionController` en vivo
  /// (p.ej. el indicador "grabando…" de la preview colapsada).
  @visibleForTesting
  void debugForceRecordingStateForTest({
    required String pageId,
    required String blockId,
    String? transcript,
    Duration? elapsed,
  }) {
    _pageId = pageId;
    _blockId = blockId;
    _state = MeetingNoteSessionState.recording;
    if (transcript != null) _transcript = transcript;
    if (elapsed != null) _elapsed = elapsed;
    notifyListeners();
  }

  /// Solo para tests: reinicia por completo el estado del singleton entre
  /// casos de test (evita fugas de estado entre tests).
  @visibleForTesting
  void debugResetForTest() {
    _cloudEtaTicker?.cancel();
    _cloudEtaTicker = null;
    _cloudProcessingFuture = null;
    _cloudCancelRequested = false;
    _cloudInkChargeSent = false;
    _cloudTranscriptAccum = '';
    _cloudTotalChunks = 0;
    _cloudProcessedChunks = 0;
    _cloudProcessingStartedAt = null;
    _pendingCloudChunks.clear();
    _runtimeErrorCode = null;
    _runtimeErrorDetail = null;
    _cloudFallbackNoticeCode = null;
    _transcript = '';
    _session = null;
    _pageId = null;
    _blockId = null;
    _state = MeetingNoteSessionState.idle;
    _lastMonologueNudgeAt = null;
    _cachedMetricsSnapshot = null;
    _cachedMetricsTranscript = null;
  }

  Future<void> cancelAndTeardown() async {
    if (_state == MeetingNoteSessionState.cloudProcessing) {
      await cancelCloudProcessingAndAwait();
      return;
    }
    _cleanupPendingChunks();
    try {
      _send({'type': MeetingWorkerCmd.shutdown});
    } catch (_) {}
    await _teardownWorker();
    _resetToIdle();
  }

  /// Cancela una subida/transcripción en curso en la nube sin tocar `_session`
  /// una vez arrancada la cancelación (evita notifyListeners/updateBlockText
  /// sobre una VaultSession que puede haberse bloqueado/dispuesto mientras
  /// `_processCloudChunks()` seguía corriendo en segundo plano).
  Future<void> cancelCloudProcessingAndAwait({
    Duration budget = const Duration(seconds: 5),
  }) async {
    if (_state != MeetingNoteSessionState.cloudProcessing) return;
    _cloudCancelRequested = true;
    _cloudFallbackNoticeCode = 'cloud_upload_cancelled';
    final future = _cloudProcessingFuture;
    if (future != null) {
      await future.timeout(budget, onTimeout: () {});
    }
    // Lo normal es que _processCloudChunks() ya se haya reseteado a idle al
    // notar la cancelación; si no llegó a tiempo dentro del budget, forzamos
    // el reset aquí para que la UI nunca quede atascada en cloudProcessing.
    if (_state == MeetingNoteSessionState.cloudProcessing) {
      _cloudCancelRequested = false;
      _cloudProcessingFuture = null;
      _resetToIdle();
    }
  }

  /// Guardado best-effort y acotado en el tiempo, pensado para llamarse
  /// justo antes de bloquear la bóveda o cerrar la app: si hay una grabación
  /// en curso, la detiene en modo "fast" (sin esperar la transcripción del
  /// último chunk) para no perder el audio/transcript ya capturado, y sin
  /// arrancar una subida a la nube nueva (eso quedaría corriendo detrás de
  /// una sesión que puede desaparecer). Si ya había una subida a la nube en
  /// curso, la cancela en vez de dejarla corriendo huérfana.
  Future<void> saveActiveRecordingBeforeTeardown({
    Duration budget = const Duration(seconds: 12),
  }) async {
    if (_state == MeetingNoteSessionState.idle ||
        _state == MeetingNoteSessionState.completed) {
      return;
    }
    if (_state == MeetingNoteSessionState.cloudProcessing) {
      await cancelCloudProcessingAndAwait();
      return;
    }
    await stop(stopTimeout: budget, fast: true, startCloudProcessing: false);
  }

  void goToMeetingPage() {
    final id = _pageId;
    final session = _session;
    if (id == null || session == null) return;
    session.selectPage(id);
  }

  Duration? estimatedCloudRemaining() {
    final startedAt = _cloudProcessingStartedAt;
    if (startedAt == null) return null;
    if (_cloudTotalChunks <= 0 || _cloudProcessedChunks <= 0) return null;
    final elapsed = DateTime.now().difference(startedAt);
    final perChunkMs = elapsed.inMilliseconds / _cloudProcessedChunks;
    final remainingChunks = _cloudTotalChunks - _cloudProcessedChunks;
    if (remainingChunks <= 0) return Duration.zero;
    final remainingMs = (perChunkMs * remainingChunks).round();
    if (remainingMs < 0) return Duration.zero;
    return Duration(milliseconds: remainingMs);
  }

  Future<void> _ensureWorkerConnected() async {
    if (_client != null) return;

    _inProcessMode = false;
    await _bindIpcServer();

    final port = _server!.port;
    final exe = Platform.resolvedExecutable;
    final workDir = File(exe).parent.path;
    AppLogger.info(
      'Starting meeting worker',
      tag: 'meeting',
      context: {'exe': exe, 'workDir': workDir, 'port': '$port'},
    );
    _workerStderr.clear();
    final process = await Process.start(
      exe,
      [
        MeetingWorkerProtocol.flagMeetingWorker,
        '${MeetingWorkerProtocol.flagIpcPort}=$port',
      ],
      mode: ProcessStartMode.normal,
      workingDirectory: workDir,
    );
    _workerProcess = process;
    _workerStderrSub = process.stderr
        .transform(utf8.decoder)
        .listen((chunk) {
      _workerStderr.write(chunk);
      AppLogger.warn(
        'meeting worker stderr',
        tag: 'meeting',
        context: {'chunk': chunk},
      );
    });
    unawaited(
      process.stdout.transform(utf8.decoder).forEach((chunk) {
        AppLogger.info(
          'meeting worker stdout',
          tag: 'meeting',
          context: {'chunk': chunk},
        );
      }),
    );

    _workerShutdownExpected = false;
    unawaited(
      process.exitCode.then((code) {
        if (_workerShutdownExpected) {
          unawaited(_teardownWorker(alreadyDead: true));
          return;
        }
        final stderrTail = _workerStderr.toString().trim();
        final detail = stderrTail.isEmpty
            ? 'exit $code (0x${(code & 0xffffffff).toRadixString(16)})'
            : 'exit $code (0x${(code & 0xffffffff).toRadixString(16)}): $stderrTail';
        AppLogger.error(
          'Meeting worker exited unexpectedly',
          tag: 'meeting',
          context: {'detail': detail},
        );
        if (_readyCompleter != null && !(_readyCompleter!.isCompleted)) {
          _readyCompleter!.completeError(
            StateError('Meeting worker exited early ($detail)'),
          );
        }
        if (isActive) {
          _runtimeErrorCode = 'worker_crashed';
          _runtimeErrorDetail = detail;
          _state = MeetingNoteSessionState.idle;
          notifyListeners();
        }
        unawaited(_teardownWorker(alreadyDead: true));
      }),
    );

    await _readyCompleter!.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw TimeoutException('Meeting worker ready timeout');
      },
    );
  }

  /// Mismo protocolo IPC, pero el host vive en el isolate de Folio.
  /// Se usa si el proceso externo crashea (p.ej. ACCESS_VIOLATION en Windows).
  Future<void> _ensureInProcessWorkerConnected() async {
    if (_client != null) return;

    _inProcessMode = true;
    final accepted = Completer<void>();
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _readyCompleter = Completer<void>();
    final port = _server!.port;

    _server!.listen((socket) {
      if (_client != null) {
        socket.destroy();
        return;
      }
      _client = socket;
      _lineBuffer.clear();
      _clientSub = socket.listen(
        _onClientData,
        onDone: _onWorkerDisconnected,
        onError: (_) => _onWorkerDisconnected(),
        cancelOnError: true,
      );
      if (!accepted.isCompleted) accepted.complete();
    });

    AppLogger.info(
      'Starting in-process meeting worker host',
      tag: 'meeting',
      context: {'port': '$port'},
    );

    final hostSocket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: const Duration(seconds: 5),
    );
    await accepted.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException('In-process meeting IPC accept timeout');
      },
    );

    unawaited(
      MeetingWorkerHost(socket: hostSocket).run().catchError((
        Object e,
        StackTrace st,
      ) {
        AppLogger.error(
          'In-process meeting host failed',
          tag: 'meeting',
          error: e,
          stackTrace: st,
        );
      }),
    );

    await _readyCompleter!.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException('In-process meeting worker ready timeout');
      },
    );
  }

  Future<void> _bindIpcServer() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _readyCompleter = Completer<void>();

    _server!.listen((socket) {
      if (_client != null) {
        socket.destroy();
        return;
      }
      _client = socket;
      _lineBuffer.clear();
      _clientSub = socket.listen(
        _onClientData,
        onDone: _onWorkerDisconnected,
        onError: (_) => _onWorkerDisconnected(),
        cancelOnError: true,
      );
    });
  }

  void _onClientData(List<int> data) {
    _lineBuffer.write(utf8.decode(data));
    var content = _lineBuffer.toString();
    while (true) {
      final idx = content.indexOf('\n');
      if (idx < 0) break;
      final line = content.substring(0, idx);
      content = content.substring(idx + 1);
      final msg = MeetingWorkerProtocol.decodeLine(line);
      if (msg != null) _handleEvent(msg);
    }
    _lineBuffer
      ..clear()
      ..write(content);
  }

  void _handleEvent(Map<String, dynamic> msg) {
    final type = '${msg['type'] ?? ''}';
    switch (type) {
      case MeetingWorkerEvent.ready:
        final c = _readyCompleter;
        if (c != null && !c.isCompleted) c.complete();
      case MeetingWorkerEvent.setupProgress:
        _setupLabel = '${msg['label'] ?? ''}';
        final prog = msg['progress'];
        _setupProgress = prog is num ? prog.toDouble() : 0;
        notifyListeners();
      case MeetingWorkerEvent.state:
        final name = '${msg['state'] ?? ''}';
        if (name == MeetingWorkerStateName.recording) {
          _state = MeetingNoteSessionState.recording;
          notifyListeners();
        } else if (name == MeetingWorkerStateName.setup) {
          _state = MeetingNoteSessionState.setup;
          notifyListeners();
        } else if (name == MeetingWorkerStateName.idle &&
            _state == MeetingNoteSessionState.setup) {
          // Error path already handled via error event.
        }
      case MeetingWorkerEvent.elapsed:
        final secs = (msg['seconds'] as num?)?.toInt() ?? 0;
        _elapsed = Duration(seconds: secs);
        notifyListeners();
      case MeetingWorkerEvent.transcribing:
        _transcribing = msg['value'] == true;
        notifyListeners();
      case MeetingWorkerEvent.transcriptDelta:
        _transcript = '${msg['fullTranscript'] ?? _transcript}';
        _runtimeErrorCode = null;
        _runtimeErrorDetail = null;
        final pageId = _pageId;
        final blockId = _blockId;
        final session = _session;
        if (pageId != null && blockId != null && session != null) {
          session.updateBlockTextStreaming(pageId, blockId, _transcript);
        }
        notifyListeners();
      case MeetingWorkerEvent.chunkReady:
        final path = '${msg['path'] ?? ''}'.trim();
        if (path.isNotEmpty) {
          _pendingCloudChunks.add(File(path));
        }
      case MeetingWorkerEvent.systemAudio:
        _systemAudioCapturing = msg['capturing'] == true;
        notifyListeners();
      case MeetingWorkerEvent.error:
        _runtimeErrorCode = '${msg['code'] ?? MeetingWorkerErrorCode.unexpected}';
        _runtimeErrorDetail = '${msg['message'] ?? ''}';
        if (_state == MeetingNoteSessionState.setup &&
            (_runtimeErrorCode == MeetingWorkerErrorCode.audioAccess ||
                _runtimeErrorCode == MeetingWorkerErrorCode.whisperInit)) {
          unawaited(_teardownWorker());
          _state = MeetingNoteSessionState.idle;
        }
        notifyListeners();
      case MeetingWorkerEvent.stopped:
        final c = _stoppedCompleter;
        if (c != null && !c.isCompleted) c.complete(msg);
      case MeetingWorkerEvent.pong:
        break;
    }
  }

  void _onWorkerDisconnected() {
    if (_stoppedCompleter != null && !(_stoppedCompleter!.isCompleted)) {
      _stoppedCompleter!.complete(<String, dynamic>{});
    }
    if (isActive && _state != MeetingNoteSessionState.cloudProcessing) {
      _runtimeErrorCode = 'worker_crashed';
      _state = MeetingNoteSessionState.idle;
      notifyListeners();
    }
  }

  void _send(Map<String, dynamic> message) {
    final client = _client;
    if (client == null) {
      throw StateError('Meeting worker not connected');
    }
    client.add(utf8.encode('${MeetingWorkerProtocol.encode(message)}\n'));
  }

  Future<void> _processCloudChunks() async {
    final chunks = List<File>.from(_pendingCloudChunks);
    _pendingCloudChunks.clear();
    final pageId = _pageId;
    final blockId = _blockId;
    final session = _session;
    if (pageId == null || blockId == null || session == null) {
      if (!_cloudCancelRequested) {
        _state = MeetingNoteSessionState.completed;
        notifyListeners();
      }
      return;
    }

    final inkCostTotal = math.max(1, (_elapsed.inSeconds / 300).ceil());
    final lang = _languageCode.trim();
    final languageArg = (lang.isEmpty || lang == 'auto') ? 'auto' : lang;
    final deadline =
        (_cloudProcessingStartedAt ?? DateTime.now())
            .add(_cloudProcessingMaxDuration);
    // Fragmentos que no llegaron a subirse con éxito (fallo terminal o
    // cancelación a mitad de proceso) — se conservan en disco para un
    // reintento posterior en vez de borrarse (ver retryCloudProcessing()).
    final remaining = <File>[];

    for (var i = 0; i < chunks.length; i++) {
      if (_cloudCancelRequested) {
        remaining.addAll(chunks.sublist(i));
        break;
      }
      if (DateTime.now().isAfter(deadline)) {
        _cloudCancelRequested = true;
        _runtimeErrorCode = 'cloud_processing_timeout';
        remaining.addAll(chunks.sublist(i));
        break;
      }

      final chunk = chunks[i];
      _cloudProcessedChunks = i + 1;
      notifyListeners();

      final chargeInk = !_cloudInkChargeSent;
      final result = await CloudTranscriptionChunkUploader.uploadChunkWithRetry(
        chunk: chunk,
        languageArg: languageArg,
        chargeInk: chargeInk,
        inkAmount: inkCostTotal,
        isCancelled: () => _cloudCancelRequested,
        maxAttempts: _cloudChunkMaxAttempts,
        retryDelays: _cloudChunkRetryDelays,
        noRetryCodes: _cloudChunkNoRetryCodes,
        pollInterval: _cloudJobPollInterval,
        pollMaxWait: _cloudJobPollMaxWait,
        onInkChargeAttempted: () => _cloudInkChargeSent = true,
      );

      if (result.cancelled) {
        remaining.add(chunk);
        remaining.addAll(chunks.sublist(i + 1));
        break;
      }

      final failure = result.failure;
      if (failure != null) {
        _cloudFallbackNoticeCode =
            failure is FolioCloudException && failure.code == 'resource-exhausted'
                ? 'ink_exhausted'
                : 'cloud_fallback';
        remaining.add(chunk);
        remaining.addAll(chunks.sublist(i + 1));
        break;
      }

      // Éxito confirmado: recién ahora es seguro borrar este fragmento.
      unawaited(chunk.delete().catchError((_) => File('')));

      final res = result.data;
      final inkRaw = res?['ink'];
      if (inkRaw is Map) {
        final ent = _entitlements;
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

      final text = '${res?['transcript'] ?? ''}';
      if (text.isNotEmpty) {
        _cloudTranscriptAccum = _cloudTranscriptAccum.isEmpty
            ? text
            : MeetingNoteTranscriptMerge.merge(_cloudTranscriptAccum, text);
      }
    }

    _pendingCloudChunks
      ..clear()
      ..addAll(remaining);

    if (_cloudCancelRequested) {
      // Cancelación explícita del usuario (o de lock/dispose): se abandona
      // del todo el intento de mejora por nube, no se deja para reintentar.
      for (final chunk in remaining) {
        unawaited(chunk.delete().catchError((_) => File('')));
      }
      _pendingCloudChunks.clear();
      _cloudCancelRequested = false;
      _cloudProcessingFuture = null;
      // Si nadie más espera este future (p.ej. el techo de 8 min se disparó
      // solo, sin que cancelCloudProcessingAndAwait() esté en curso), nos
      // encargamos nosotros mismos de sacar a la UI de cloudProcessing.
      _resetToIdle();
      return;
    }

    // Guarda el progreso parcial aunque queden fragmentos pendientes de
    // reintento — antes, cualquier fallo descartaba también lo ya logrado.
    if (_cloudTranscriptAccum.isNotEmpty) {
      _transcript = _cloudTranscriptAccum;
      session.updateBlockText(pageId, blockId, _cloudTranscriptAccum);
    }

    _cloudEtaTicker?.cancel();
    _cloudEtaTicker = null;
    _cloudProcessingStartedAt = null;
    _state = MeetingNoteSessionState.completed;
    notifyListeners();
  }

  void _cleanupPendingChunks() {
    for (final chunk in _pendingCloudChunks) {
      unawaited(chunk.delete().catchError((_) => File('')));
    }
    _pendingCloudChunks.clear();
  }

  void _failIdle(String code, String? detail) {
    _runtimeErrorCode = code;
    _runtimeErrorDetail = detail;
    _state = MeetingNoteSessionState.idle;
    notifyListeners();
  }

  void _resetToIdle() {
    _cloudEtaTicker?.cancel();
    _cloudEtaTicker = null;
    _state = MeetingNoteSessionState.idle;
    _pageId = null;
    _blockId = null;
    notifyListeners();
  }

  Future<void> _teardownWorker({bool alreadyDead = false}) async {
    _workerShutdownExpected = true;
    await _clientSub?.cancel();
    _clientSub = null;
    try {
      await _client?.close();
    } catch (_) {}
    _client = null;

    await _workerStderrSub?.cancel();
    _workerStderrSub = null;

    if (!alreadyDead && !_inProcessMode) {
      final proc = _workerProcess;
      if (proc != null) {
        try {
          proc.kill();
        } catch (_) {}
      }
    }
    _workerProcess = null;
    _inProcessMode = false;

    try {
      await _server?.close();
    } catch (_) {}
    _server = null;
    _readyCompleter = null;
    _stoppedCompleter = null;
    _lineBuffer.clear();
  }
}
