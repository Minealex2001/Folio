import 'dart:convert';

/// Protocolo JSON por líneas (NDJSON) entre Folio y el proceso worker.
abstract final class MeetingWorkerProtocol {
  static const flagMeetingWorker = '--meeting-worker';
  static const flagIpcPort = '--ipc-port';

  static int? parseIpcPort(List<String> args) {
    for (final arg in args) {
      if (arg.startsWith('$flagIpcPort=')) {
        return int.tryParse(arg.substring(flagIpcPort.length + 1));
      }
      if (arg == flagIpcPort) {
        final i = args.indexOf(arg);
        if (i >= 0 && i + 1 < args.length) {
          return int.tryParse(args[i + 1]);
        }
      }
    }
    return null;
  }

  static bool isWorkerArgs(List<String> args) =>
      args.contains(flagMeetingWorker);

  static String encode(Map<String, dynamic> message) => jsonEncode(message);

  static Map<String, dynamic>? decodeLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry('$k', v));
      }
    } catch (_) {}
    return null;
  }
}

abstract final class MeetingWorkerCmd {
  static const start = 'start';
  static const stop = 'stop';
  static const ping = 'ping';
  static const shutdown = 'shutdown';
}

abstract final class MeetingWorkerEvent {
  static const ready = 'ready';
  static const setupProgress = 'setup_progress';
  static const state = 'state';
  static const elapsed = 'elapsed';
  static const transcribing = 'transcribing';
  static const transcriptDelta = 'transcript_delta';
  static const chunkReady = 'chunk_ready';
  static const systemAudio = 'system_audio';
  static const error = 'error';
  static const stopped = 'stopped';
  static const pong = 'pong';
}

abstract final class MeetingWorkerErrorCode {
  static const audioAccess = 'audio_access';
  static const whisperInit = 'whisper_init';
  static const chunkTranscription = 'chunk_transcription';
  static const stopFailed = 'stop_failed';
  static const unexpected = 'unexpected';
}

abstract final class MeetingWorkerStateName {
  static const idle = 'idle';
  static const setup = 'setup';
  static const recording = 'recording';
  static const stopped = 'stopped';
}
