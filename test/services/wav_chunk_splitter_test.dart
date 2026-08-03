import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/wav_chunk_splitter.dart';

const _sampleRate = 16000;
const _channels = 1;
const _bitsPerSample = 16;
const _blockAlign = _channels * (_bitsPerSample ~/ 8);
const _byteRate = _sampleRate * _blockAlign;

/// Escribe un WAV PCM16 mono 16kHz sintético de puro silencio, con el mismo
/// formato de header de 44 bytes que produce la app (offsets replicados a
/// propósito, independientes de la implementación bajo test).
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

int _readDataSize(File wavFile) {
  final bytes = wavFile.readAsBytesSync();
  final bd = ByteData.sublistView(bytes, 0, 44);
  return bd.getUint32(40, Endian.little);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folio_wav_splitter_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('WavChunkSplitter.splitToChunks', () {
    test('audio más largo que un chunk: reparte en fragmentos de tamaño exacto salvo el último', () async {
      final wav = await _writeSilenceWav(tempDir, 'source.wav', 40);
      final outDir = Directory('${tempDir.path}${Platform.pathSeparator}out');

      final chunks = await WavChunkSplitter.splitToChunks(
        wavFile: wav,
        outputDir: outDir,
        chunkSeconds: 15,
      );

      expect(chunks, hasLength(3));
      expect(_readDataSize(chunks[0]), _byteRate * 15);
      expect(_readDataSize(chunks[1]), _byteRate * 15);
      expect(_readDataSize(chunks[2]), _byteRate * 10);
      for (final c in chunks) {
        expect(c.existsSync(), isTrue);
      }
    });

    test('audio más corto que un chunk: un solo fragmento de longitud exacta', () async {
      final wav = await _writeSilenceWav(tempDir, 'source.wav', 5);
      final outDir = Directory('${tempDir.path}${Platform.pathSeparator}out');

      final chunks = await WavChunkSplitter.splitToChunks(
        wavFile: wav,
        outputDir: outDir,
        chunkSeconds: 15,
      );

      expect(chunks, hasLength(1));
      expect(_readDataSize(chunks[0]), _byteRate * 5);
    });

    test('audio múltiplo exacto del tamaño de chunk: sin fragmento final vacío', () async {
      final wav = await _writeSilenceWav(tempDir, 'source.wav', 30);
      final outDir = Directory('${tempDir.path}${Platform.pathSeparator}out');

      final chunks = await WavChunkSplitter.splitToChunks(
        wavFile: wav,
        outputDir: outDir,
        chunkSeconds: 15,
      );

      expect(chunks, hasLength(2));
      expect(_readDataSize(chunks[0]), _byteRate * 15);
      expect(_readDataSize(chunks[1]), _byteRate * 15);
    });

    test('WAV vacío (sin datos): no genera fragmentos ni lanza', () async {
      final wav = await _writeSilenceWav(tempDir, 'source.wav', 0);
      final outDir = Directory('${tempDir.path}${Platform.pathSeparator}out');

      final chunks = await WavChunkSplitter.splitToChunks(
        wavFile: wav,
        outputDir: outDir,
        chunkSeconds: 15,
      );

      expect(chunks, isEmpty);
    });

    test('archivo inexistente: no genera fragmentos ni lanza', () async {
      final missing = File(
        '${tempDir.path}${Platform.pathSeparator}no_existe.wav',
      );
      final outDir = Directory('${tempDir.path}${Platform.pathSeparator}out');

      final chunks = await WavChunkSplitter.splitToChunks(
        wavFile: missing,
        outputDir: outDir,
      );

      expect(chunks, isEmpty);
    });
  });

  group('WavChunkSplitter.estimateDuration', () {
    test('calcula la duración a partir del dataSize del header', () async {
      final wav = await _writeSilenceWav(tempDir, 'source.wav', 37);
      final duration = await WavChunkSplitter.estimateDuration(wav);
      expect(duration, const Duration(seconds: 37));
    });

    test('archivo inexistente devuelve Duration.zero', () async {
      final missing = File(
        '${tempDir.path}${Platform.pathSeparator}no_existe.wav',
      );
      final duration = await WavChunkSplitter.estimateDuration(missing);
      expect(duration, Duration.zero);
    });
  });
}
