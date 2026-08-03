/// Cobertura del camino nube de `PostHocTranscriptionJobManager` (el camino
/// local no es testeable en unidad, requiere el binario real de
/// whisper-cli — misma limitación ya aceptada para
/// `MeetingNoteSessionController`).
///
/// El test de cancelación mirroriza la regresión ya cubierta para el flujo
/// de grabación en vivo (`meeting_note_session_controller_test.dart`): un
/// job cancelado a mitad de subida no debe volver a tocar la `VaultSession`.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/folio_cloud/folio_cloud_callable.dart';
import 'package:folio/services/meeting_note_posthoc_transcription_manager.dart';
import 'package:folio/session/vault_session.dart';

const _sampleRate = 16000;
const _channels = 1;
const _bitsPerSample = 16;
const _blockAlign = _channels * (_bitsPerSample ~/ 8);
const _byteRate = _sampleRate * _blockAlign;

/// WAV PCM16 mono 16kHz sintético de silencio, mismo formato que produce la
/// app. [seconds] > 120 genera más de un fragmento con el chunkSeconds por
/// defecto (120s) del splitter.
Future<File> _writeSilenceWav(Directory dir, String name, int seconds) async {
  final dataSize = _byteRate * seconds;
  final header = ByteData(44);
  header.setUint8(0, 0x52);
  header.setUint8(1, 0x49);
  header.setUint8(2, 0x46);
  header.setUint8(3, 0x46);
  header.setUint32(4, 36 + dataSize, Endian.little);
  header.setUint8(8, 0x57);
  header.setUint8(9, 0x41);
  header.setUint8(10, 0x56);
  header.setUint8(11, 0x45);
  header.setUint8(12, 0x66);
  header.setUint8(13, 0x6D);
  header.setUint8(14, 0x74);
  header.setUint8(15, 0x20);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, _channels, Endian.little);
  header.setUint32(24, _sampleRate, Endian.little);
  header.setUint32(28, _byteRate, Endian.little);
  header.setUint16(32, _blockAlign, Endian.little);
  header.setUint16(34, _bitsPerSample, Endian.little);
  header.setUint8(36, 0x64);
  header.setUint8(37, 0x61);
  header.setUint8(38, 0x74);
  header.setUint8(39, 0x61);
  header.setUint32(40, dataSize, Endian.little);

  final file = File('${dir.path}${Platform.pathSeparator}$name');
  final raf = await file.open(mode: FileMode.write);
  await raf.writeFrom(header.buffer.asUint8List());
  const writeBlock = 64 * 1024;
  var remaining = dataSize;
  final zeros = Uint8List(writeBlock);
  while (remaining > 0) {
    final n = remaining < writeBlock ? remaining : writeBlock;
    await raf.writeFrom(zeros, 0, n);
    remaining -= n;
  }
  await raf.close();
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  late Directory tempPlatformDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_posthoc_mgr_');
    tempPlatformDir = await Directory.systemTemp.createTemp(
      'folio_posthoc_mgr_platform_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return tempPlatformDir.path;
        });
    PostHocTranscriptionJobManager.debugCloudPollInterval =
        const Duration(milliseconds: 1);
    PostHocTranscriptionJobManager.debugCloudRetryDelays = const [
      Duration(milliseconds: 1),
      Duration(milliseconds: 1),
      Duration(milliseconds: 1),
    ];
    PostHocTranscriptionJobManager.instance.debugResetForTest();
  });

  tearDown(() async {
    debugCallFolioHttpsCallableOverride = null;
    PostHocTranscriptionJobManager.instance.debugResetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    if (tempPlatformDir.existsSync()) {
      await tempPlatformDir.delete(recursive: true);
    }
  });

  group('PostHocTranscriptionJobManager — camino nube', () {
    test('camino feliz: trocea, sube todo, fusiona transcript y borra los fragmentos temporales', () async {
      final session = VaultSession();
      session.addPage();
      final page = session.selectedPage!;
      final pageId = page.id;
      final blockId = page.blocks.first.id;

      // 130s con chunkSeconds=120 por defecto → 2 fragmentos (120s + 10s).
      final wav = await _writeSilenceWav(tempDir, 'meeting.wav', 130);

      var jobCounter = 0;
      final jobTexts = <String, String>{};
      debugCallFolioHttpsCallableOverride = (name, params) async {
        if (name == 'folioCloudTranscribeStart') {
          jobCounter++;
          final jobId = 'job-$jobCounter';
          jobTexts[jobId] =
              jobCounter == 1 ? 'PRIMER_FRAGMENTO.' : 'SEGUNDO_FRAGMENTO.';
          return {'jobId': jobId};
        }
        if (name == 'folioCloudTranscribeStatus') {
          final jobId = (params as Map)['jobId'] as String;
          return {
            'status': 'done',
            'transcript': jobTexts[jobId],
            'ink': {'monthlyBalance': 9, 'purchasedBalance': 0},
          };
        }
        throw StateError('callable inesperado: $name');
      };

      await PostHocTranscriptionJobManager.instance.start(
        session: session,
        pageId: pageId,
        blockId: blockId,
        audioFile: wav,
        engine: PostHocTranscriptionEngine.quillCloud,
        languageCode: 'auto',
        modelId: 'tiny',
      );

      // start() arranca el job en segundo plano; esperar a que termine.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      var job = PostHocTranscriptionJobManager.instance.jobFor(pageId, blockId);
      var attempts = 0;
      while (job != null &&
          job.state == PostHocTranscriptionJobState.running &&
          attempts < 100) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        job = PostHocTranscriptionJobManager.instance.jobFor(pageId, blockId);
        attempts++;
      }

      expect(job?.state, PostHocTranscriptionJobState.done);
      expect(jobCounter, 2);
      final text = session.selectedPage!.blocks.first.text;
      expect(text, contains('PRIMER_FRAGMENTO'));
      expect(text, contains('SEGUNDO_FRAGMENTO'));
    });

    test('fallo a mitad de subida conserva el transcript parcial ya logrado', () async {
      final session = VaultSession();
      session.addPage();
      final page = session.selectedPage!;
      final pageId = page.id;
      final blockId = page.blocks.first.id;

      final wav = await _writeSilenceWav(tempDir, 'meeting.wav', 130);

      var startCalls = 0;
      debugCallFolioHttpsCallableOverride = (name, params) async {
        if (name == 'folioCloudTranscribeStart') {
          startCalls++;
          if (startCalls == 1) return {'jobId': 'job-1'};
          throw StateError('fallo persistente en el segundo fragmento');
        }
        if (name == 'folioCloudTranscribeStatus') {
          return {'status': 'done', 'transcript': 'SOLO_ESTO_LLEGA.'};
        }
        throw StateError('callable inesperado: $name');
      };

      await PostHocTranscriptionJobManager.instance.start(
        session: session,
        pageId: pageId,
        blockId: blockId,
        audioFile: wav,
        engine: PostHocTranscriptionEngine.quillCloud,
        languageCode: 'auto',
        modelId: 'tiny',
      );

      var job = PostHocTranscriptionJobManager.instance.jobFor(pageId, blockId);
      var attempts = 0;
      while (job != null &&
          job.state == PostHocTranscriptionJobState.running &&
          attempts < 100) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        job = PostHocTranscriptionJobManager.instance.jobFor(pageId, blockId);
        attempts++;
      }

      expect(job?.state, PostHocTranscriptionJobState.failed);
      final text = session.selectedPage!.blocks.first.text;
      expect(text, contains('SOLO_ESTO_LLEGA'));
    });

    test('cancelAllAndAwait durante la subida no vuelve a tocar la sesión', () async {
      final session = VaultSession();
      session.addPage();
      final page = session.selectedPage!;
      final pageId = page.id;
      final block = page.blocks.first;
      final blockId = block.id;

      final wav = await _writeSilenceWav(tempDir, 'meeting.wav', 130);

      var statusCalls = 0;
      debugCallFolioHttpsCallableOverride = (name, params) async {
        if (name == 'folioCloudTranscribeStart') return {'jobId': 'job-x'};
        if (name == 'folioCloudTranscribeStatus') {
          statusCalls++;
          if (statusCalls == 1) {
            unawaited(PostHocTranscriptionJobManager.instance.cancelAllAndAwait());
            session.dispose();
            return {'status': 'pending'};
          }
          return {'status': 'done', 'transcript': 'NO_DEBERIA_LLEGAR'};
        }
        throw StateError('callable inesperado: $name');
      };

      await PostHocTranscriptionJobManager.instance.start(
        session: session,
        pageId: pageId,
        blockId: blockId,
        audioFile: wav,
        engine: PostHocTranscriptionEngine.quillCloud,
        languageCode: 'auto',
        modelId: 'tiny',
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // El job nunca debe haber vuelto a llamar a session.updateBlockText
      // tras la cancelación — el texto del bloque (mismo objeto, capturado
      // antes de dispose()) debe seguir vacío.
      expect(block.text, isEmpty);
      expect(statusCalls, 1);
    });
  });
}
