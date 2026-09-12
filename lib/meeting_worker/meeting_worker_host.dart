import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../services/audio_mixer_service.dart';
import '../services/diarization_service.dart';
import '../services/meeting_note_transcript_merge.dart';
import '../services/system_audio_service.dart';
import '../services/whisper_service.dart';
import 'meeting_worker_protocol.dart';

/// Orquesta captura + Whisper en el proceso worker y habla NDJSON por socket.
class MeetingWorkerHost {
  MeetingWorkerHost({required this.socket});

  final Socket socket;

  StreamSubscription<AudioChunkEvent>? _chunkSub;
  StreamSubscription<List<int>>? _socketSub;
  Timer? _elapsedTimer;
  Future<void> _chunkChain = Future<void>.value();

  String _transcript = '';
  String? _diarizationSessionId;
  String? _language;
  String? _modelId;
  bool _runLocalWhisper = false;
  bool _saveCloudChunks = false;
  bool _busy = false;
  int _elapsedSeconds = 0;
  final _done = Completer<void>();

  Future<void> run() async {
    _emit({
      'type': MeetingWorkerEvent.ready,
    });

    final lineBuffer = StringBuffer();
    _socketSub = socket.listen(
      (data) {
        lineBuffer.write(utf8.decode(data));
        var content = lineBuffer.toString();
        while (true) {
          final idx = content.indexOf('\n');
          if (idx < 0) break;
          final line = content.substring(0, idx);
          content = content.substring(idx + 1);
          final msg = MeetingWorkerProtocol.decodeLine(line);
          if (msg != null) {
            unawaited(_handleCommand(msg));
          }
        }
        lineBuffer
          ..clear()
          ..write(content);
      },
      onDone: () {
        unawaited(_shutdown(killAudio: true));
      },
      onError: (_) {
        unawaited(_shutdown(killAudio: true));
      },
      cancelOnError: true,
    );

    await _done.future;
  }

  Future<void> _handleCommand(Map<String, dynamic> msg) async {
    final type = '${msg['type'] ?? ''}';
    switch (type) {
      case MeetingWorkerCmd.ping:
        _emit({'type': MeetingWorkerEvent.pong});
      case MeetingWorkerCmd.shutdown:
        await _shutdown(killAudio: true);
      case MeetingWorkerCmd.start:
        await _start(msg);
      case MeetingWorkerCmd.stop:
        await _stop(msg);
      default:
        _emitError(
          MeetingWorkerErrorCode.unexpected,
          'Unknown command: $type',
        );
    }
  }

  Future<void> _start(Map<String, dynamic> msg) async {
    if (_busy) {
      _emitError(MeetingWorkerErrorCode.unexpected, 'Worker already busy');
      return;
    }
    _busy = true;
    _transcript = '';
    _elapsedSeconds = 0;
    _runLocalWhisper = msg['runLocalWhisper'] == true;
    _saveCloudChunks = msg['saveCloudChunks'] == true;
    _modelId = '${msg['modelId'] ?? ''}'.trim();
    final lang = '${msg['language'] ?? 'auto'}'.trim();
    _language = (lang.isEmpty || lang == 'auto') ? null : lang;
    final sessionId = '${msg['sessionId'] ?? ''}'.trim();
    final micDeviceId = '${msg['micDeviceId'] ?? ''}'.trim();
    final systemDeviceId = '${msg['systemDeviceId'] ?? ''}'.trim();

    _emit({
      'type': MeetingWorkerEvent.state,
      'state': MeetingWorkerStateName.setup,
    });

    if (_runLocalWhisper) {
      try {
        await WhisperService.instance.ensureReady(
          modelId: _modelId!.isEmpty ? null : _modelId,
          onProgress: (label, prog) {
            _emit({
              'type': MeetingWorkerEvent.setupProgress,
              'label': label,
              'progress': prog,
            });
          },
        );
      } catch (e) {
        _busy = false;
        _emitError(MeetingWorkerErrorCode.whisperInit, '$e');
        _emit({
          'type': MeetingWorkerEvent.state,
          'state': MeetingWorkerStateName.idle,
        });
        return;
      }
    } else {
      _emit({
        'type': MeetingWorkerEvent.setupProgress,
        'label': '',
        'progress': 1.0,
      });
    }

    bool ok;
    try {
      ok = await AudioMixerService.instance.start(
        micDeviceId: micDeviceId.isEmpty ? null : micDeviceId,
        systemOutputDeviceId:
            systemDeviceId.isEmpty ? null : systemDeviceId,
        trackChannelMeta: true,
      );
    } catch (_) {
      ok = false;
    }

    if (!ok) {
      _busy = false;
      _emitError(MeetingWorkerErrorCode.audioAccess, 'audio_access');
      _emit({
        'type': MeetingWorkerEvent.state,
        'state': MeetingWorkerStateName.idle,
      });
      return;
    }

    _emit({
      'type': MeetingWorkerEvent.systemAudio,
      'capturing': SystemAudioService.instance.isCapturing,
    });

    if (_runLocalWhisper) {
      final sid = sessionId.isNotEmpty ? sessionId : const Uuid().v4();
      _diarizationSessionId = sid;
      DiarizationService.instance.startSession(sid);
    }

    _chunkChain = Future<void>.value();
    _chunkSub = AudioMixerService.instance.chunkStream.listen((event) {
      _chunkChain = _chunkChain
          .then((_) => _onChunk(event))
          .catchError((_) {});
    });

    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds += 1;
      _emit({
        'type': MeetingWorkerEvent.elapsed,
        'seconds': _elapsedSeconds,
      });
    });

    _emit({
      'type': MeetingWorkerEvent.state,
      'state': MeetingWorkerStateName.recording,
    });
  }

  Future<void> _onChunk(AudioChunkEvent event) async {
    final chunkFile = event.file;
    if (!_runLocalWhisper && !_saveCloudChunks) {
      unawaited(chunkFile.delete().catchError((_) => File('')));
      return;
    }

    if (_saveCloudChunks) {
      _emit({
        'type': MeetingWorkerEvent.chunkReady,
        'path': chunkFile.path,
      });
    }

    if (!_runLocalWhisper) return;

    _emit({'type': MeetingWorkerEvent.transcribing, 'value': true});

    final text = await WhisperService.instance.transcribe(
      chunkFile,
      language: _language,
      modelId: _modelId!.isEmpty ? null : _modelId,
    );

    var finalText = text;
    if (text.isNotEmpty) {
      final sid = _diarizationSessionId;
      final diarized = await DiarizationService.instance.diarizeChunk(
        audioChunk: chunkFile,
        transcript: text,
        language: _language ?? 'auto',
        sessionId: sid ?? 'meeting-worker',
        channelWindows: event.channelWindows,
      );
      if (diarized != null && diarized.trim().isNotEmpty) {
        finalText = diarized.trim();
      }
    }

    if (!_saveCloudChunks) {
      unawaited(chunkFile.delete().catchError((_) => File('')));
    }

    if (finalText.isNotEmpty) {
      _transcript = MeetingNoteTranscriptMerge.merge(_transcript, finalText);
      _emit({
        'type': MeetingWorkerEvent.transcriptDelta,
        'text': finalText,
        'fullTranscript': _transcript,
      });
    } else {
      _emitError(
        MeetingWorkerErrorCode.chunkTranscription,
        WhisperService.instance.lastError ?? 'chunk_transcription',
      );
    }

    _emit({'type': MeetingWorkerEvent.transcribing, 'value': false});
  }

  Future<void> _stop(Map<String, dynamic> msg) async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    await _chunkSub?.cancel();
    _chunkSub = null;

    final fast = msg['fast'] == true;
    if (!fast) {
      // Esperar a que terminen los chunks en vuelo, acotado: si Whisper va
      // atrasado (modelo grande, hardware lento, muchos chunks en cola),
      // antes esto podía tardar hasta 5 minutos en responder al comando
      // `stop` — el usuario veía "Detener" sin ningún efecto durante ese
      // rato. Con este límite se pierde como mucho la transcripción del
      // último tramo en cola, pero el botón siempre responde en segundos.
      try {
        await _chunkChain.timeout(const Duration(seconds: 20));
      } catch (_) {}
    }
    // En modo fast (guardado acotado antes de bloquear/cerrar la app) no
    // esperamos la transcripción del último chunk en vuelo — solo el WAV ya
    // capturado, para no bloquear al llamador más de unos segundos.

    final sid = _diarizationSessionId;
    if (sid != null) {
      DiarizationService.instance.endSession(sid);
      _diarizationSessionId = null;
    }

    final destPath = '${msg['destPath'] ?? ''}'.trim();
    if (destPath.isEmpty) {
      _busy = false;
      _emitError(MeetingWorkerErrorCode.stopFailed, 'missing destPath');
      _emit({
        'type': MeetingWorkerEvent.state,
        'state': MeetingWorkerStateName.idle,
      });
      return;
    }

    File? wavFile;
    try {
      wavFile = await AudioMixerService.instance.stop(destPath: destPath);
    } catch (e) {
      _busy = false;
      _emitError(MeetingWorkerErrorCode.stopFailed, '$e');
      _emit({
        'type': MeetingWorkerEvent.state,
        'state': MeetingWorkerStateName.idle,
      });
      return;
    }

    _busy = false;
    _emit({
      'type': MeetingWorkerEvent.stopped,
      'wavPath': wavFile?.path ?? '',
      'transcript': _transcript,
      'channelMeta': AudioMixerService.instance.channelMeta,
    });
    _emit({
      'type': MeetingWorkerEvent.state,
      'state': MeetingWorkerStateName.stopped,
    });
  }

  Future<void> _shutdown({required bool killAudio}) async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _chunkSub?.cancel();
    _chunkSub = null;
    await _socketSub?.cancel();
    _socketSub = null;

    if (killAudio && AudioMixerService.instance.isActive) {
      try {
        final temp = Directory.systemTemp;
        final dump = '${temp.path}${Platform.pathSeparator}folio_meeting_abort_${DateTime.now().millisecondsSinceEpoch}.wav';
        await AudioMixerService.instance.stop(destPath: dump);
        unawaited(File(dump).delete().catchError((_) => File('')));
      } catch (_) {}
    }

    final sid = _diarizationSessionId;
    if (sid != null) {
      DiarizationService.instance.endSession(sid);
      _diarizationSessionId = null;
    }

    try {
      await socket.close();
    } catch (_) {}

    if (!_done.isCompleted) _done.complete();
  }

  void _emit(Map<String, dynamic> message) {
    try {
      socket.add(utf8.encode('${MeetingWorkerProtocol.encode(message)}\n'));
    } catch (_) {}
  }

  void _emitError(String code, String message) {
    _emit({
      'type': MeetingWorkerEvent.error,
      'code': code,
      'message': message,
    });
  }
}
