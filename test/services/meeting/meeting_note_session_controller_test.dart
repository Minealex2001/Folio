/// Cobertura del pipeline de subida/transcripción en la nube de
/// `MeetingNoteSessionController` (`_processCloudChunks`), que hasta ahora no
/// tenía ningún test automatizado.
///
/// Usa los seams `@visibleForTesting` añadidos junto con el fix:
/// - `debugCallFolioHttpsCallableOverride` sustituye la llamada HTTP real.
/// - `debugStartCloudProcessingForTest` arranca el procesamiento en la nube
///   directamente (sin pasar por el proceso worker real, no viable en
///   `flutter test`).
/// - `debugCloudJobPollInterval`/`debugCloudChunkRetryDelays` aceleran el
///   polling y los backoffs para que los tests no esperen segundos reales.
///
/// El test más importante es "cancelar a mitad de subida no vuelve a tocar
/// la sesión": es la regresión directa del bug reportado por el usuario
/// (congelamiento/crash al bloquear la bóveda o cerrar la app a mitad de
/// transcripción en la nube, con el botón "Detener" sin efecto).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/folio_cloud/folio_cloud_callable.dart';
import 'package:folio/services/folio_cloud/folio_cloud_exception.dart';
import 'package:folio/services/meeting_note_session_controller.dart';
import 'package:folio/session/vault_session.dart';

Future<File> _writeChunk(Directory dir, String name, String content) async {
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsString(content);
  return file;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_meeting_cloud_');
    MeetingNoteSessionController.debugCloudJobPollInterval =
        const Duration(milliseconds: 1);
    MeetingNoteSessionController.debugCloudChunkRetryDelays = const [
      Duration(milliseconds: 1),
      Duration(milliseconds: 1),
      Duration(milliseconds: 1),
    ];
    MeetingNoteSessionController.instance.debugResetForTest();
  });

  tearDown(() async {
    debugCallFolioHttpsCallableOverride = null;
    MeetingNoteSessionController.instance.debugResetForTest();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MeetingNoteSessionController — procesamiento en la nube', () {
    test(
      'camino feliz: todos los fragmentos se suben, se fusiona el transcript y se borran los archivos',
      () async {
        final session = VaultSession();
        session.addPage();
        final page = session.selectedPage!;
        final pageId = page.id;
        final blockId = page.blocks.first.id;

        final chunk0 = await _writeChunk(tempDir, 'c0.wav', 'audio-0');
        final chunk1 = await _writeChunk(tempDir, 'c1.wav', 'audio-1');

        var startCalls = 0;
        debugCallFolioHttpsCallableOverride = (name, params) async {
          if (name == 'folioCloudTranscribeStart') {
            startCalls++;
            return {'jobId': 'job-$startCalls'};
          }
          if (name == 'folioCloudTranscribeStatus') {
            final jobId = (params as Map)['jobId'] as String;
            final text = jobId == 'job-1' ? 'FRAGMENTO_CERO.' : 'FRAGMENTO_UNO.';
            return {
              'status': 'done',
              'transcript': text,
              'ink': {'monthlyBalance': 10, 'purchasedBalance': 0},
            };
          }
          throw StateError('callable inesperado: $name');
        };

        await MeetingNoteSessionController.instance
            .debugStartCloudProcessingForTest(
              session: session,
              pageId: pageId,
              blockId: blockId,
              chunkFiles: [chunk0, chunk1],
            );

        expect(
          MeetingNoteSessionController.instance.state,
          MeetingNoteSessionState.completed,
        );
        expect(
          MeetingNoteSessionController.instance.canRetryCloudUpload,
          isFalse,
        );
        final text = session.selectedPage!.blocks.first.text;
        expect(text, contains('FRAGMENTO_CERO'));
        expect(text, contains('FRAGMENTO_UNO'));
        expect(chunk0.existsSync(), isFalse);
        expect(chunk1.existsSync(), isFalse);
      },
    );

    test(
      'cancelar a mitad de subida no vuelve a tocar la sesión (regresión del crash reportado)',
      () async {
        final session = VaultSession();
        session.addPage();
        final page = session.selectedPage!;
        final pageId = page.id;
        final blockId = page.blocks.first.id;
        final originalText = page.blocks.first.text;

        final chunk0 = await _writeChunk(tempDir, 'c0.wav', 'audio-0');

        var statusCalls = 0;
        debugCallFolioHttpsCallableOverride = (name, params) async {
          if (name == 'folioCloudTranscribeStart') {
            return {'jobId': 'job-1'};
          }
          if (name == 'folioCloudTranscribeStatus') {
            statusCalls++;
            if (statusCalls == 1) {
              // Simula lock()/dispose() pidiendo cancelar justo después del
              // primer poll (p.ej. el usuario bloqueó la bóveda a mitad de
              // la subida) y disponiendo la VaultSession, como en el bug
              // reportado.
              unawaited(
                MeetingNoteSessionController.instance
                    .cancelCloudProcessingAndAwait(),
              );
              session.dispose();
              return {'status': 'pending'};
            }
            // Si el loop no respeta la cancelación, llegaría hasta aquí y
            // tocaría una sesión ya disposed.
            return {
              'status': 'done',
              'transcript': 'NO DEBERIA USARSE',
            };
          }
          throw StateError('callable inesperado: $name');
        };

        await expectLater(
          MeetingNoteSessionController.instance
              .debugStartCloudProcessingForTest(
                session: session,
                pageId: pageId,
                blockId: blockId,
                chunkFiles: [chunk0],
              ),
          completes,
        );

        expect(
          MeetingNoteSessionController.instance.state,
          MeetingNoteSessionState.idle,
        );
        expect(statusCalls, 1);
      },
    );

    test(
      'fallo persistente en un fragmento: no se borran los pendientes y retryCloudProcessing() los completa',
      () async {
        final session = VaultSession();
        session.addPage();
        final page = session.selectedPage!;
        final pageId = page.id;
        final blockId = page.blocks.first.id;

        final chunk0 = await _writeChunk(tempDir, 'c0.wav', 'audio-0');
        final chunk1 = await _writeChunk(tempDir, 'c1.wav', 'audio-1');
        final chunk2 = await _writeChunk(tempDir, 'c2.wav', 'audio-2');

        var failChunk1 = true;
        var jobCounter = 0;
        final jobTexts = <String, String>{};
        debugCallFolioHttpsCallableOverride = (name, params) async {
          if (name == 'folioCloudTranscribeStart') {
            final audioB64 = (params as Map)['audioBase64'] as String;
            final content = utf8.decode(base64Decode(audioB64));
            if (content == 'audio-1' && failChunk1) {
              // Simula un blip de red transitorio en el segundo fragmento.
              throw const SocketExceptionForTest();
            }
            jobCounter++;
            final jobId = 'job-$jobCounter';
            jobTexts[jobId] = switch (content) {
              'audio-0' => 'FRAGMENTO_CERO.',
              'audio-1' => 'FRAGMENTO_UNO.',
              _ => 'FRAGMENTO_DOS.',
            };
            return {'jobId': jobId};
          }
          if (name == 'folioCloudTranscribeStatus') {
            final jobId = (params as Map)['jobId'] as String;
            return {
              'status': 'done',
              'transcript': jobTexts[jobId],
              'ink': {'monthlyBalance': 5, 'purchasedBalance': 0},
            };
          }
          throw StateError('callable inesperado: $name');
        };

        await MeetingNoteSessionController.instance
            .debugStartCloudProcessingForTest(
              session: session,
              pageId: pageId,
              blockId: blockId,
              chunkFiles: [chunk0, chunk1, chunk2],
            );

        // Chunk 0 se subió bien; chunk 1 falló tras agotar reintentos y
        // detuvo el loop — chunk 2 nunca se intentó. Ninguno de los dos
        // pendientes debe borrarse.
        expect(
          MeetingNoteSessionController.instance.state,
          MeetingNoteSessionState.completed,
        );
        expect(
          MeetingNoteSessionController.instance.canRetryCloudUpload,
          isTrue,
        );
        expect(chunk1.existsSync(), isTrue);
        expect(chunk2.existsSync(), isTrue);
        var text = session.selectedPage!.blocks.first.text;
        expect(text, contains('FRAGMENTO_CERO'));
        expect(text, isNot(contains('FRAGMENTO_UNO')));

        // Ahora "se recupera la red" y el usuario pulsa reintentar.
        failChunk1 = false;
        await MeetingNoteSessionController.instance.retryCloudProcessing();

        expect(
          MeetingNoteSessionController.instance.state,
          MeetingNoteSessionState.completed,
        );
        expect(
          MeetingNoteSessionController.instance.canRetryCloudUpload,
          isFalse,
        );
        expect(chunk1.existsSync(), isFalse);
        expect(chunk2.existsSync(), isFalse);
        text = session.selectedPage!.blocks.first.text;
        expect(text, contains('FRAGMENTO_CERO'));
        expect(text, contains('FRAGMENTO_UNO'));
        expect(text, contains('FRAGMENTO_DOS'));
      },
    );
  });
}

/// Excepción genérica (no FolioCloudException) para simular un fallo de red
/// transitorio, que el loop de subida debe tratar como reintentable.
class SocketExceptionForTest implements Exception {
  const SocketExceptionForTest();
  @override
  String toString() => 'SocketExceptionForTest: simulated network blip';
}
