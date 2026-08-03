import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/folio_cloud/cloud_transcription_chunk_uploader.dart';
import 'package:folio/services/folio_cloud/folio_cloud_callable.dart';
import 'package:folio/services/folio_cloud/folio_cloud_exception.dart';

void main() {
  late Directory tempDir;
  late File chunkFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_chunk_uploader_');
    chunkFile = File('${tempDir.path}${Platform.pathSeparator}chunk.wav');
    await chunkFile.writeAsString('fake-audio-bytes');
  });

  tearDown(() async {
    debugCallFolioHttpsCallableOverride = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CloudTranscriptionChunkUploader.uploadChunkWithRetry', () {
    test('éxito al primer intento', () async {
      var startCalls = 0;
      debugCallFolioHttpsCallableOverride = (name, params) async {
        if (name == 'folioCloudTranscribeStart') {
          startCalls++;
          return {'jobId': 'job-1'};
        }
        if (name == 'folioCloudTranscribeStatus') {
          return {
            'status': 'done',
            'transcript': 'hola mundo',
            'ink': {'monthlyBalance': 3, 'purchasedBalance': 0},
          };
        }
        throw StateError('callable inesperado: $name');
      };

      final result = await CloudTranscriptionChunkUploader.uploadChunkWithRetry(
        chunk: chunkFile,
        languageArg: 'auto',
        chargeInk: true,
        inkAmount: 1,
        isCancelled: () => false,
        pollInterval: const Duration(milliseconds: 1),
      );

      expect(result.cancelled, isFalse);
      expect(result.failure, isNull);
      expect(result.data?['transcript'], 'hola mundo');
      expect(startCalls, 1);
    });

    test('fallo transitorio en el primer intento, éxito en el reintento', () async {
      var startCalls = 0;
      debugCallFolioHttpsCallableOverride = (name, params) async {
        if (name == 'folioCloudTranscribeStart') {
          startCalls++;
          if (startCalls == 1) {
            throw FolioCloudException(code: 'unavailable', message: 'blip');
          }
          return {'jobId': 'job-2'};
        }
        if (name == 'folioCloudTranscribeStatus') {
          return {'status': 'done', 'transcript': 'recuperado'};
        }
        throw StateError('callable inesperado: $name');
      };

      final result = await CloudTranscriptionChunkUploader.uploadChunkWithRetry(
        chunk: chunkFile,
        languageArg: 'auto',
        chargeInk: false,
        inkAmount: 1,
        isCancelled: () => false,
        retryDelays: const [Duration(milliseconds: 1), Duration(milliseconds: 1)],
        pollInterval: const Duration(milliseconds: 1),
      );

      expect(result.cancelled, isFalse);
      expect(result.failure, isNull);
      expect(result.data?['transcript'], 'recuperado');
      expect(startCalls, 2);
    });

    test('código sin reintento (resource-exhausted) falla rápido sin reintentar', () async {
      var startCalls = 0;
      debugCallFolioHttpsCallableOverride = (name, params) async {
        startCalls++;
        throw FolioCloudException(code: 'resource-exhausted', message: 'sin ink');
      };

      final result = await CloudTranscriptionChunkUploader.uploadChunkWithRetry(
        chunk: chunkFile,
        languageArg: 'auto',
        chargeInk: true,
        inkAmount: 1,
        isCancelled: () => false,
        retryDelays: const [Duration(milliseconds: 1), Duration(milliseconds: 1)],
      );

      expect(result.cancelled, isFalse);
      expect(result.failure, isA<FolioCloudException>());
      expect((result.failure as FolioCloudException).code, 'resource-exhausted');
      expect(startCalls, 1);
    });

    test('agota los reintentos en errores genéricos retryables', () async {
      var startCalls = 0;
      debugCallFolioHttpsCallableOverride = (name, params) async {
        startCalls++;
        throw Exception('network blip');
      };

      final result = await CloudTranscriptionChunkUploader.uploadChunkWithRetry(
        chunk: chunkFile,
        languageArg: 'auto',
        chargeInk: false,
        inkAmount: 1,
        isCancelled: () => false,
        maxAttempts: 3,
        retryDelays: const [
          Duration(milliseconds: 1),
          Duration(milliseconds: 1),
          Duration(milliseconds: 1),
        ],
      );

      expect(result.cancelled, isFalse);
      expect(result.failure, isNotNull);
      expect(startCalls, 3);
    });

    test('cancelación a mitad de poll devuelve cancelled sin lanzar', () async {
      var statusCalls = 0;
      var cancelled = false;
      debugCallFolioHttpsCallableOverride = (name, params) async {
        if (name == 'folioCloudTranscribeStart') {
          return {'jobId': 'job-3'};
        }
        if (name == 'folioCloudTranscribeStatus') {
          statusCalls++;
          if (statusCalls == 1) {
            cancelled = true;
            return {'status': 'pending'};
          }
          return {'status': 'done', 'transcript': 'no debería llegar aquí'};
        }
        throw StateError('callable inesperado: $name');
      };

      final result = await CloudTranscriptionChunkUploader.uploadChunkWithRetry(
        chunk: chunkFile,
        languageArg: 'auto',
        chargeInk: false,
        inkAmount: 1,
        isCancelled: () => cancelled,
        pollInterval: const Duration(milliseconds: 1),
      );

      expect(result.cancelled, isTrue);
      expect(result.data, isNull);
      expect(result.failure, isNull);
      expect(statusCalls, 1);
    });

    test('onInkChargeAttempted se llama solo cuando chargeInk es true', () async {
      var inkChargeAttempts = 0;
      debugCallFolioHttpsCallableOverride = (name, params) async {
        if (name == 'folioCloudTranscribeStart') return {'jobId': 'job-4'};
        if (name == 'folioCloudTranscribeStatus') {
          return {'status': 'done', 'transcript': 'ok'};
        }
        throw StateError('callable inesperado: $name');
      };

      await CloudTranscriptionChunkUploader.uploadChunkWithRetry(
        chunk: chunkFile,
        languageArg: 'auto',
        chargeInk: true,
        inkAmount: 1,
        isCancelled: () => false,
        pollInterval: const Duration(milliseconds: 1),
        onInkChargeAttempted: () => inkChargeAttempts++,
      );
      expect(inkChargeAttempts, 1);

      inkChargeAttempts = 0;
      await CloudTranscriptionChunkUploader.uploadChunkWithRetry(
        chunk: chunkFile,
        languageArg: 'auto',
        chargeInk: false,
        inkAmount: 1,
        isCancelled: () => false,
        pollInterval: const Duration(milliseconds: 1),
        onInkChargeAttempted: () => inkChargeAttempts++,
      );
      expect(inkChargeAttempts, 0);
    });
  });
}
