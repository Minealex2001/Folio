import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../session/vault_session.dart';
import 'folio_cloud/cloud_transcription_chunk_uploader.dart';
import 'folio_cloud/folio_cloud_entitlements.dart';
import 'meeting_note_transcript_merge.dart';
import 'wav_chunk_splitter.dart';
import 'whisper_service.dart';

enum PostHocTranscriptionEngine { local, quillCloud }

enum PostHocTranscriptionJobState { running, done, failed, cancelled }

/// Estado de una transcripción a posteriori en curso para un bloque de nota
/// de reunión concreto. Vive en [PostHocTranscriptionJobManager], no en
/// ningún widget — sobrevive a que el bloque se desmonte (scroll, cambio de
/// página) igual que `MeetingNoteSessionController` no depende del ciclo de
/// vida de ningún widget.
class PostHocTranscriptionJob extends ChangeNotifier {
  PostHocTranscriptionJob({
    required this.pageId,
    required this.blockId,
    required this.engine,
  });

  final String pageId;
  final String blockId;
  final PostHocTranscriptionEngine engine;

  PostHocTranscriptionJobState _state = PostHocTranscriptionJobState.running;
  int _totalChunks = 0;
  int _processedChunks = 0;
  String? _errorMessage;
  bool _cancelRequested = false;

  PostHocTranscriptionJobState get state => _state;
  int get totalChunks => _totalChunks;
  int get processedChunks => _processedChunks;
  String? get errorMessage => _errorMessage;
  bool get cancelRequested => _cancelRequested;

  void _requestCancel() {
    if (_cancelRequested) return;
    _cancelRequested = true;
    notifyListeners();
  }

  void _setProgress({int? total, int? processed}) {
    if (total != null) _totalChunks = total;
    if (processed != null) _processedChunks = processed;
    notifyListeners();
  }

  void _finish(PostHocTranscriptionJobState state, {String? errorMessage}) {
    _state = state;
    _errorMessage = errorMessage;
    notifyListeners();
  }
}

/// Manager singleton de transcripciones a posteriori — permite pedir la
/// transcripción de una nota de reunión ya guardada (con audio pero sin
/// texto) sin pasar por `MeetingNoteSessionController` (que está atado a
/// UNA grabación en vivo a la vez). Cada job vive en [_jobs] por
/// `pageId::blockId`, así que puede haber varias transcripciones a
/// posteriori corriendo a la vez para bloques distintos.
class PostHocTranscriptionJobManager extends ChangeNotifier {
  PostHocTranscriptionJobManager._();
  static final PostHocTranscriptionJobManager instance =
      PostHocTranscriptionJobManager._();

  // Mutables (con valores de producción por defecto) solo para poder
  // acelerar el polling/backoff en tests sin esperas reales de segundos —
  // mismo patrón que `MeetingNoteSessionController`.
  static Duration _cloudPollInterval = const Duration(seconds: 3);
  static List<Duration> _cloudRetryDelays = const [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  @visibleForTesting
  static set debugCloudPollInterval(Duration interval) =>
      _cloudPollInterval = interval;

  @visibleForTesting
  static set debugCloudRetryDelays(List<Duration> delays) =>
      _cloudRetryDelays = delays;

  final Map<String, PostHocTranscriptionJob> _jobs = {};
  final Map<String, Future<void>> _runningFutures = {};

  static String _key(String pageId, String blockId) => '$pageId::$blockId';

  PostHocTranscriptionJob? jobFor(String pageId, String blockId) =>
      _jobs[_key(pageId, blockId)];

  bool isRunning(String pageId, String blockId) =>
      jobFor(pageId, blockId)?.state == PostHocTranscriptionJobState.running;

  Future<void> start({
    required VaultSession session,
    required String pageId,
    required String blockId,
    required File audioFile,
    required PostHocTranscriptionEngine engine,
    required String languageCode,
    required String modelId,
    FolioCloudEntitlementsController? entitlements,
  }) async {
    if (isRunning(pageId, blockId)) return;
    final key = _key(pageId, blockId);
    final job = PostHocTranscriptionJob(
      pageId: pageId,
      blockId: blockId,
      engine: engine,
    );
    _jobs[key] = job;
    notifyListeners();

    final future = engine == PostHocTranscriptionEngine.local
        ? _runLocal(
            job,
            session: session,
            audioFile: audioFile,
            languageCode: languageCode,
            modelId: modelId,
          )
        : _runCloud(
            job,
            session: session,
            audioFile: audioFile,
            languageCode: languageCode,
            entitlements: entitlements,
          );
    _runningFutures[key] = future;
    unawaited(
      future.whenComplete(() {
        _runningFutures.remove(key);
        notifyListeners();
      }),
    );
  }

  void cancel(String pageId, String blockId) {
    jobFor(pageId, blockId)?._requestCancel();
  }

  /// Igual que `MeetingNoteSessionController.cancelCloudProcessingAndAwait`:
  /// pensado para llamarse desde los mismos puntos donde ya se llama a
  /// `saveActiveRecordingBeforeTeardown()` (bloquear la bóveda, cerrar la
  /// app) — marca cancelación en todos los jobs en curso y espera de forma
  /// acotada a que dejen de tocar la sesión antes de que `lock()`/`dispose()`
  /// continúen.
  Future<void> cancelAllAndAwait({
    Duration budget = const Duration(seconds: 12),
  }) async {
    for (final job in _jobs.values) {
      if (job.state == PostHocTranscriptionJobState.running) {
        job._requestCancel();
      }
    }
    final futures = _runningFutures.values.toList();
    if (futures.isEmpty) return;
    await Future.wait(futures).timeout(budget, onTimeout: () => <void>[]);
  }

  @visibleForTesting
  void debugResetForTest() {
    _jobs.clear();
    _runningFutures.clear();
  }

  Future<void> _runLocal(
    PostHocTranscriptionJob job, {
    required VaultSession session,
    required File audioFile,
    required String languageCode,
    required String modelId,
  }) async {
    try {
      await WhisperService.instance.ensureReady(modelId: modelId);
      if (job.cancelRequested) {
        job._finish(PostHocTranscriptionJobState.cancelled);
        return;
      }

      final lang = languageCode.trim();
      final language = (lang.isEmpty || lang == 'auto') ? null : lang;
      final text = await WhisperService.instance.transcribe(
        audioFile,
        language: language,
        modelId: modelId,
      );

      if (job.cancelRequested) {
        job._finish(PostHocTranscriptionJobState.cancelled);
        return;
      }
      if (text.trim().isEmpty) {
        job._finish(
          PostHocTranscriptionJobState.failed,
          errorMessage: WhisperService.instance.lastError,
        );
        return;
      }

      session.updateBlockText(job.pageId, job.blockId, text);
      job._finish(PostHocTranscriptionJobState.done);
    } catch (e) {
      if (job.cancelRequested) {
        job._finish(PostHocTranscriptionJobState.cancelled);
      } else {
        job._finish(PostHocTranscriptionJobState.failed, errorMessage: '$e');
      }
    }
  }

  Future<void> _runCloud(
    PostHocTranscriptionJob job, {
    required VaultSession session,
    required File audioFile,
    required String languageCode,
    FolioCloudEntitlementsController? entitlements,
  }) async {
    Directory? chunkDir;
    try {
      final lang = languageCode.trim();
      final languageArg = (lang.isEmpty || lang == 'auto') ? 'auto' : lang;

      final duration = await WavChunkSplitter.estimateDuration(audioFile);
      final inkCostTotal = math.max(1, (duration.inSeconds / 300).ceil());

      final tempDir = await getTemporaryDirectory();
      chunkDir = Directory(
        p.join(tempDir.path, 'folio_posthoc_${const Uuid().v4()}'),
      );

      final chunks = await WavChunkSplitter.splitToChunks(
        wavFile: audioFile,
        outputDir: chunkDir,
      );
      job._setProgress(total: chunks.length, processed: 0);

      if (chunks.isEmpty) {
        job._finish(
          PostHocTranscriptionJobState.failed,
          errorMessage: 'audio_empty',
        );
        return;
      }

      var accum = '';
      var inkChargeSent = false;
      Object? terminalFailure;

      for (var i = 0; i < chunks.length; i++) {
        if (job.cancelRequested) break;
        job._setProgress(processed: i + 1);

        final chargeInk = !inkChargeSent;
        final result = await CloudTranscriptionChunkUploader.uploadChunkWithRetry(
          chunk: chunks[i],
          languageArg: languageArg,
          chargeInk: chargeInk,
          inkAmount: inkCostTotal,
          isCancelled: () => job.cancelRequested,
          onInkChargeAttempted: () => inkChargeSent = true,
          pollInterval: _cloudPollInterval,
          retryDelays: _cloudRetryDelays,
        );

        if (result.cancelled) break;

        if (result.failure != null) {
          terminalFailure = result.failure;
          break;
        }

        unawaited(chunks[i].delete().catchError((_) => chunks[i]));

        final data = result.data;
        final inkRaw = data?['ink'];
        if (inkRaw is Map) {
          final monthly = (inkRaw['monthlyBalance'] as num?)?.toInt();
          final purchased = (inkRaw['purchasedBalance'] as num?)?.toInt();
          if (entitlements != null &&
              monthly != null &&
              purchased != null &&
              monthly >= 0 &&
              purchased >= 0) {
            entitlements.applyInkBalancesFromCloudAi(
              monthlyBalance: monthly,
              purchasedBalance: purchased,
            );
          }
        }

        final text = '${data?['transcript'] ?? ''}';
        if (text.isNotEmpty) {
          accum = accum.isEmpty
              ? text
              : MeetingNoteTranscriptMerge.merge(accum, text);
        }
      }

      if (job.cancelRequested) {
        job._finish(PostHocTranscriptionJobState.cancelled);
        return;
      }

      // Guarda el progreso parcial aunque queden fragmentos sin subir — no
      // se pierde lo ya transcrito si el job falla a mitad de camino.
      if (accum.isNotEmpty) {
        session.updateBlockText(job.pageId, job.blockId, accum);
      }

      if (terminalFailure != null) {
        job._finish(
          PostHocTranscriptionJobState.failed,
          errorMessage: '$terminalFailure',
        );
        return;
      }

      job._finish(PostHocTranscriptionJobState.done);
    } catch (e) {
      if (job.cancelRequested) {
        job._finish(PostHocTranscriptionJobState.cancelled);
      } else {
        job._finish(PostHocTranscriptionJobState.failed, errorMessage: '$e');
      }
    } finally {
      final dir = chunkDir;
      if (dir != null) {
        unawaited(dir.delete(recursive: true).catchError((_) => dir));
      }
    }
  }
}
