import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/generated/app_localizations.dart';

/// Versión del binario y modelo que usa este servicio.
/// Actualizar el SHA cuando se cambie de versión.
class _WhisperRelease {
  static const String binaryVersion = '1.7.6';

  static String get binaryUrl {
    if (Platform.isWindows) {
      return 'https://github.com/ggerganov/whisper.cpp/releases/download/v$binaryVersion/whisper-bin-x64.zip';
    } else if (Platform.isMacOS) {
      return 'https://github.com/ggerganov/whisper.cpp/releases/download/v$binaryVersion/whisper-macos-arm64.zip';
    } else {
      return 'https://github.com/ggerganov/whisper.cpp/releases/download/v$binaryVersion/whisper-linux-x64.zip';
    }
  }

  static String get binaryFilename {
    if (Platform.isWindows) return 'whisper-cli.exe';
    return 'whisper-cli';
  }
}

class WhisperModelOption {
  const WhisperModelOption({
    required this.id,
    required this.filename,
    required this.url,
    required this.approxSizeMb,
  });

  final String id;
  final String filename;
  final String url;
  final int approxSizeMb;

  /// Etiqueta legible localizada (p.ej. "Tiny (rápido)"). Requiere
  /// [AppLocalizations] porque estos modelos se referencian tanto desde la
  /// UI principal como desde el worker de reuniones (sin BuildContext).
  String localizedLabel(AppLocalizations l10n) {
    switch (id) {
      case 'tiny':
        return l10n.whisperModelTiny;
      case 'base':
        return l10n.whisperModelBase;
      case 'small':
        return l10n.whisperModelSmall;
      case 'medium':
        return l10n.whisperModelMedium;
      case 'turbo':
        return l10n.whisperModelTurbo;
      default:
        return id;
    }
  }
}

/// Servicio que gestiona descarga e invocación de whisper.cpp como subprocess.
/// Toda la transcripción es 100% local, sin llamadas a APIs externas.
class WhisperService {
  WhisperService._();
  static final WhisperService instance = WhisperService._();

  static const List<WhisperModelOption> supportedModels = [
    WhisperModelOption(
      id: 'tiny',
      filename: 'ggml-tiny.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
      approxSizeMb: 75,
    ),
    WhisperModelOption(
      id: 'base',
      filename: 'ggml-base-q8_0.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q8_0.bin',
      approxSizeMb: 78,
    ),
    WhisperModelOption(
      id: 'small',
      filename: 'ggml-small-q8_0.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q8_0.bin',
      approxSizeMb: 252,
    ),
    WhisperModelOption(
      id: 'medium',
      filename: 'ggml-medium-q8_0.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q8_0.bin',
      approxSizeMb: 785,
    ),
    WhisperModelOption(
      id: 'turbo',
      filename: 'ggml-large-v3-turbo-q8_0.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin',
      approxSizeMb: 834,
    ),
  ];

  /// Nombres de .bin antiguos o sustituidos; se pueden borrar al cambiar de modelo.
  static const List<String> legacyWhisperModelFilenames = [
    'ggml-base.bin',
    'ggml-small.bin',
  ];

  String? _binaryPath;
  String? _modelPath;
  String? _lastError;
  String _activeModelId = 'tiny';

  /// Idioma para los mensajes de progreso/error de este servicio. Este
  /// servicio no tiene acceso a un `BuildContext` (se usa también desde el
  /// worker de reuniones), así que se resuelve vía [lookupAppLocalizations].
  /// Actualizar junto con `VaultSession.titleLocale` al cambiar el idioma de la app.
  Locale locale = const Locale('es');

  AppLocalizations get _l10n => lookupAppLocalizations(locale);

  String? get lastError => _lastError;
  String get activeModelId => _activeModelId;

  WhisperModelOption? modelById(String id) {
    final safe = id.trim();
    for (final m in supportedModels) {
      if (m.id == safe) return m;
    }
    return null;
  }

  WhisperModelOption _resolveModel(String? requestedModelId) {
    final wanted = requestedModelId?.trim();
    if (wanted != null && wanted.isNotEmpty) {
      final byId = modelById(wanted);
      if (byId != null) return byId;
    }
    final active = modelById(_activeModelId);
    if (active != null) return active;
    return supportedModels.first;
  }

  /// [onProgress] recibe valores 0.0–1.0 durante la descarga.
  Future<void> ensureReady({
    String? modelId,
    void Function(String label, double progress)? onProgress,
  }) async {
    final model = _resolveModel(modelId);
    if (_binaryPath != null &&
        _modelPath != null &&
        _activeModelId == model.id &&
        await File(_binaryPath!).exists() &&
        await File(_modelPath!).exists()) {
      return;
    }

    final supportDir = await getApplicationSupportDirectory();
    final whisperDir = Directory(p.join(supportDir.path, 'whisper'));
    await whisperDir.create(recursive: true);

    // Binario
    _binaryPath = await _ensureBinary(whisperDir, onProgress: onProgress);
    // Modelo
    _modelPath = await _ensureModel(whisperDir, model, onProgress: onProgress);
    _activeModelId = model.id;
    await _deleteOtherWhisperModelBins(whisperDir, keepFilename: model.filename);
  }

  /// Borra otros GGML conocidos en [whisperDir], dejando solo el modelo activo.
  Future<void> _deleteOtherWhisperModelBins(
    Directory whisperDir, {
    required String keepFilename,
  }) async {
    final known = <String>{
      ...supportedModels.map((m) => m.filename),
      ...legacyWhisperModelFilenames,
    };
    try {
      await for (final entity in whisperDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.endsWith('.bin')) continue;
        if (name == keepFilename) continue;
        if (!known.contains(name)) continue;
        await entity.delete().catchError((_) => File(''));
      }
    } catch (_) {}
  }

  /// Transcribe el [wavFile] y devuelve el texto.
  /// Devuelve cadena vacía si hay error (no lanza excepción).
  Future<String> transcribe(
    File wavFile, {
    String? language,
    String? modelId,
  }) async {
    _lastError = null;

    final requestedModel = modelById(modelId?.trim() ?? '');
    if (requestedModel != null && requestedModel.id != _activeModelId) {
      try {
        await ensureReady(modelId: requestedModel.id);
      } catch (e) {
        _lastError = _l10n.whisperErrorPreparingModel(
          requestedModel.localizedLabel(_l10n),
          '$e',
        );
        return '';
      }
    }

    if (_binaryPath == null || _modelPath == null) {
      _lastError = _l10n.whisperErrorEngineNotInitialized;
      return '';
    }
    if (!await File(_binaryPath!).exists()) {
      _lastError = _l10n.whisperErrorCliNotFound(_binaryPath!);
      return '';
    }
    if (!await File(_modelPath!).exists()) {
      _lastError = _l10n.whisperErrorModelNotFound(_modelPath!);
      return '';
    }

    final txtOutput = '${wavFile.path}.txt';
    try {
      final args = [
        '--model',
        _modelPath!,
        '--file',
        wavFile.path,
        '--output-txt',
        '--output-file',
        wavFile.path,
        '--no-prints',
        if (language != null) ...['-l', language],
      ];
      final result = await Process.run(
        _binaryPath!,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) {
        final err = (result.stderr as String?)?.trim();
        final out = (result.stdout as String?)?.trim();
        final detail = err?.isNotEmpty == true ? err : out;
        _lastError = _l10n.whisperErrorCliFailed(
          result.exitCode,
          detail != null && detail.isNotEmpty ? ': $detail' : '',
        );
        return '';
      }
      final out = File(txtOutput);
      if (!await out.exists()) {
        _lastError = _l10n.whisperErrorNoOutputFile(txtOutput);
        return '';
      }
      final text = (await out.readAsString()).trim();
      await out.delete().catchError((_) => File(''));
      return text;
    } catch (e) {
      _lastError = _l10n.whisperErrorRunningCli('$e');
      return '';
    }
  }

  bool get isReady => _binaryPath != null && _modelPath != null;

  /// Ejecuta whisper.cpp con tinydiarize local y devuelve el texto bruto
  /// que incluye marcadores [SPEAKER_TURN] cuando el binario/modelo los soporta.
  ///
  /// Devuelve cadena vacia si no fue posible ejecutar tdrz.
  Future<String> transcribeWithTdrzRaw(
    File wavFile, {
    String? language,
  }) async {
    _lastError = null;

    try {
      await ensureReady();
    } catch (e) {
      _lastError = _l10n.whisperErrorPreparingLocalDiarization('$e');
      return '';
    }

    if (_binaryPath == null || _modelPath == null) {
      _lastError = _l10n.whisperErrorLocalEngineNotInitialized;
      return '';
    }

    if (!await File(_binaryPath!).exists()) {
      _lastError = _l10n.whisperErrorCliNotFound(_binaryPath!);
      return '';
    }
    if (!await File(_modelPath!).exists()) {
      _lastError = _l10n.whisperErrorModelNotFound(_modelPath!);
      return '';
    }

    final txtOutput = '${wavFile.path}.txt';
    try {
      final args = [
        '--model',
        _modelPath!,
        '--file',
        wavFile.path,
        '--output-txt',
        '--output-file',
        wavFile.path,
        '-tdrz',
        if (language != null && language.trim().isNotEmpty) ...['-l', language],
      ];

      final result = await Process.run(
        _binaryPath!,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      if (result.exitCode != 0) {
        final err = (result.stderr as String?)?.trim();
        final out = (result.stdout as String?)?.trim();
        final detail = err?.isNotEmpty == true ? err : out;
        _lastError = _l10n.whisperErrorCliFailedTdrz(
          result.exitCode,
          detail != null && detail.isNotEmpty ? ': $detail' : '',
        );
        return '';
      }

      final outFile = File(txtOutput);
      final txt = await outFile.exists() ? (await outFile.readAsString()).trim() : '';
      await outFile.delete().catchError((_) => File(''));

      final stdoutText = ((result.stdout as String?) ?? '').trim();
      final stderrText = ((result.stderr as String?) ?? '').trim();

      bool hasSpeakerMarker(String s) {
        if (s.isEmpty) return false;
        return s.contains('[SPEAKER_TURN]') ||
            s.contains('SPEAKER_TURN') ||
            RegExp(r'\bspeaker\s*turn\b', caseSensitive: false).hasMatch(s) ||
            RegExp(r'\[\s*speaker\s*\d+\s*\]', caseSensitive: false).hasMatch(s);
      }

      if (hasSpeakerMarker(stdoutText)) return stdoutText;
      if (hasSpeakerMarker(txt)) return txt;
      if (hasSpeakerMarker(stderrText)) return stderrText;

      // Si no hay marcadores, devolvemos vacío para forzar fallback controlado.
      _lastError = _l10n.whisperErrorNoSpeakerMarkers;
      return '';
    } catch (e) {
      _lastError = _l10n.whisperErrorRunningCliTdrz('$e');
      return '';
    }
  }

  // ────────────────────────────────────────────────────────── internals

  Future<String> _ensureBinary(
    Directory dir, {
    void Function(String, double)? onProgress,
  }) async {
    final existingPath = await _findBinaryPath(dir);
    if (existingPath != null) {
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', existingPath]);
      }
      return existingPath;
    }

    final binPath = p.join(dir.path, _WhisperRelease.binaryFilename);
    final bin = File(binPath);
    if (await bin.exists()) {
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', binPath]);
      }
      return binPath;
    }

    onProgress?.call(_l10n.whisperDownloadingEngine, 0.0);

    // Descargar ZIP
    final zipPath = p.join(dir.path, 'whisper_bin.zip');
    await _downloadWithProgress(
      _WhisperRelease.binaryUrl,
      zipPath,
      onProgress: (p) =>
          onProgress?.call(_l10n.whisperDownloadingEngine, p * 0.5),
    );

    // Extraer
    onProgress?.call(_l10n.whisperInstallingEngine, 0.55);
    final zipFile = File(zipPath);
    await _extractZip(zipFile, dir);
    await zipFile.delete().catchError((_) => File(''));

    final resolvedPath = await _findBinaryPath(dir);
    if (resolvedPath == null) {
      throw StateError(
        _l10n.whisperErrorBinaryNotFoundAfterExtract(
          _WhisperRelease.binaryFilename,
          zipPath,
        ),
      );
    }

    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', resolvedPath]);
    }

    onProgress?.call(_l10n.whisperEngineReady, 1.0);
    return resolvedPath;
  }

  Future<String> _ensureModel(
    Directory dir,
    WhisperModelOption model, {
    void Function(String, double)? onProgress,
  }) async {
    final modelPath = p.join(dir.path, model.filename);
    final modelFile = File(modelPath);
    if (await modelFile.exists()) return modelPath;

    final label = model.localizedLabel(_l10n);
    onProgress?.call(
      _l10n.whisperDownloadingModel(label, model.approxSizeMb),
      0.0,
    );
    await _downloadWithProgress(
      model.url,
      modelPath,
      onProgress: (p) => onProgress?.call(
        _l10n.whisperDownloadingModel(label, model.approxSizeMb),
        p,
      ),
    );
    onProgress?.call(_l10n.whisperModelReady(label), 1.0);
    return modelPath;
  }

  Future<void> _downloadWithProgress(
    String url,
    String destPath, {
    void Function(double)? onProgress,
  }) async {
    final client = http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          _l10n.whisperErrorDownloadFailed(response.statusCode, url),
        );
      }
      final total = response.contentLength ?? 0;
      var received = 0;
      sink = File(destPath).openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink?.close();
      client.close();
    }
  }

  Future<void> _extractZip(File zipFile, Directory dest) async {
    if (Platform.isWindows) {
      final tarResult = await Process.run('tar', [
        '-xf',
        zipFile.path,
        '-C',
        dest.path,
      ]);
      if (tarResult.exitCode == 0) return;

      final zipEscaped = zipFile.path.replaceAll("'", "''");
      final destEscaped = dest.path.replaceAll("'", "''");
      final psScript =
          r"$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath '" +
          zipEscaped +
          r"' -DestinationPath '" +
          destEscaped +
          r"' -Force";

      final psResult = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        psScript,
      ]);
      if (psResult.exitCode != 0) {
        final tarErr = '${tarResult.stderr}'.trim();
        final psErr = '${psResult.stderr}'.trim();
        throw StateError(
          _l10n.whisperErrorZipExtractWindows(
            tarResult.exitCode,
            tarErr.isNotEmpty ? ' ($tarErr)' : '',
            psResult.exitCode,
            psErr.isNotEmpty ? ' ($psErr)' : '',
          ),
        );
      }
    } else {
      final result = await Process.run('unzip', [
        '-o',
        zipFile.path,
        '-d',
        dest.path,
      ]);
      if (result.exitCode != 0) {
        throw StateError(_l10n.whisperErrorZipExtractUnix);
      }
    }
  }

  Future<String?> _findBinaryPath(Directory dir) async {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          p.basename(entity.path) == _WhisperRelease.binaryFilename) {
        return entity.path;
      }
    }
    return null;
  }
}
