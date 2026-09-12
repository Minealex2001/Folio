import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'folio_cloud_callable.dart';
import 'folio_cloud_exception.dart';

/// Resultado de subir un fragmento de audio a transcribir en la nube.
/// Exactamente uno de [data]/[failure] es no nulo, salvo cuando [cancelled]
/// es true (en cuyo caso ninguno lo es — quien llama no debe tocar sesión ni
/// estado tras una cancelación, solo abandonar).
class CloudChunkTranscriptionResult {
  CloudChunkTranscriptionResult._({this.data, this.failure, required this.cancelled});

  factory CloudChunkTranscriptionResult.success(Map<String, dynamic> data) =>
      CloudChunkTranscriptionResult._(data: data, cancelled: false);

  factory CloudChunkTranscriptionResult.failure(Object failure) =>
      CloudChunkTranscriptionResult._(failure: failure, cancelled: false);

  factory CloudChunkTranscriptionResult.cancelled() =>
      CloudChunkTranscriptionResult._(cancelled: true);

  final Map<String, dynamic>? data;
  final Object? failure;
  final bool cancelled;
}

/// Subida+reintento de un fragmento de audio al job async de transcripción
/// del backend (`ai/transcribe-async` + polling), compartido entre la
/// grabación en vivo (`MeetingNoteSessionController`) y la transcripción a
/// posteriori. No lee ningún estado de instancia/singleton — la cancelación
/// y los tiempos de poll/backoff se reciben como parámetros, así que quien
/// llama controla por completo cuándo es seguro tocar su propia sesión con
/// el resultado (evita el tipo de bug ya arreglado antes en esta sesión: un
/// loop de subida que sigue tocando una `VaultSession` ya bloqueada/disposed
/// tras cancelarse).
class CloudTranscriptionChunkUploader {
  CloudTranscriptionChunkUploader._();

  static const int defaultMaxAttempts = 3;
  static const List<Duration> defaultRetryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];
  static const Set<String> defaultNoRetryCodes = {
    'resource-exhausted',
    'unauthenticated',
    'permission-denied',
  };
  static const Duration defaultPollInterval = Duration(seconds: 3);
  static const Duration defaultPollMaxWait = Duration(minutes: 4);

  /// Sube [chunk] con reintento+backoff. [isCancelled] se comprueba antes de
  /// cada intento y una vez más al terminar, con prioridad sobre cualquier
  /// éxito/fallo — si devuelve true en cualquiera de esos puntos, el
  /// resultado es [CloudChunkTranscriptionResult.cancelled] sin importar lo
  /// que haya pasado con la subida en sí.
  static Future<CloudChunkTranscriptionResult> uploadChunkWithRetry({
    required File chunk,
    required String languageArg,
    required bool chargeInk,
    required int inkAmount,
    required bool Function() isCancelled,
    int maxAttempts = defaultMaxAttempts,
    List<Duration> retryDelays = defaultRetryDelays,
    Set<String> noRetryCodes = defaultNoRetryCodes,
    Duration pollInterval = defaultPollInterval,
    Duration pollMaxWait = defaultPollMaxWait,
    void Function()? onInkChargeAttempted,
  }) async {
    Map<String, dynamic>? data;
    Object? failure;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (isCancelled()) break;
      try {
        if (chargeInk) onInkChargeAttempted?.call();
        data = await _transcribeChunkViaJob(
          chunk: chunk,
          languageArg: languageArg,
          chargeInk: chargeInk,
          inkAmount: inkAmount,
          isCancelled: isCancelled,
          pollInterval: pollInterval,
          pollMaxWait: pollMaxWait,
        );
        failure = null;
        break;
      } on FolioCloudException catch (e) {
        failure = e;
        if (noRetryCodes.contains(e.code) || attempt == maxAttempts - 1) {
          break;
        }
        await Future<void>.delayed(retryDelays[attempt]);
      } catch (e) {
        failure = e;
        if (attempt == maxAttempts - 1) break;
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }

    if (isCancelled()) return CloudChunkTranscriptionResult.cancelled();
    if (failure != null) return CloudChunkTranscriptionResult.failure(failure);
    if (data == null) return CloudChunkTranscriptionResult.cancelled();
    return CloudChunkTranscriptionResult.success(data);
  }

  /// Inicia el job (`folioCloudTranscribeStart`) y hace polling
  /// (`folioCloudTranscribeStatus`) hasta `done`/`failed`/timeout. Devuelve
  /// `null` si [isCancelled] se vuelve true mientras se espera — en ese caso
  /// no se lanza excepción, para que el llamador no lo trate como un fallo
  /// reintentable.
  static Future<Map<String, dynamic>?> _transcribeChunkViaJob({
    required File chunk,
    required String languageArg,
    required bool chargeInk,
    required int inkAmount,
    required bool Function() isCancelled,
    required Duration pollInterval,
    required Duration pollMaxWait,
  }) async {
    final bytes = await chunk.readAsBytes();
    final payload = <String, dynamic>{
      'audioBase64': base64Encode(bytes),
      'language': languageArg,
      'chargeInk': chargeInk,
      if (chargeInk) 'inkAmount': inkAmount,
    };

    final startRes = await callFolioHttpsCallable(
      'folioCloudTranscribeStart',
      payload,
    );
    if (isCancelled()) return null;

    final jobId = startRes is Map ? '${startRes['jobId'] ?? ''}'.trim() : '';
    if (jobId.isEmpty) {
      throw FolioCloudException(
        message: 'folioCloudTranscribeStart no devolvió jobId',
        code: 'internal',
      );
    }

    final pollDeadline = DateTime.now().add(pollMaxWait);
    while (true) {
      if (isCancelled()) return null;
      if (DateTime.now().isAfter(pollDeadline)) {
        throw FolioCloudException(
          message: 'Timeout esperando el job de transcripción $jobId',
          code: 'deadline-exceeded',
        );
      }
      await Future<void>.delayed(pollInterval);
      if (isCancelled()) return null;

      final statusRes = await callFolioHttpsCallable(
        'folioCloudTranscribeStatus',
        <String, dynamic>{'jobId': jobId},
      );
      final status = statusRes is Map ? '${statusRes['status'] ?? ''}' : '';
      if (status == 'done') {
        return statusRes is Map
            ? Map<String, dynamic>.from(statusRes)
            : <String, dynamic>{};
      }
      if (status == 'failed') {
        final err = statusRes is Map ? '${statusRes['error'] ?? ''}' : '';
        throw FolioCloudException(
          message: err.isEmpty ? 'Transcription job failed' : err,
          code: 'internal',
        );
      }
      // status == 'pending': seguir esperando.
    }
  }
}
