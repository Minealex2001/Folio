import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Trocea un WAV PCM ya grabado (formato fijo de 44 bytes de header, el
/// mismo que escribe `AudioMixerService`) en fragmentos WAV independientes,
/// para transcripción en la nube a posteriori. No depende de
/// `AudioMixerService` (sus métodos de header son privados y están atados a
/// estado de grabación en vivo) — el formato es fijo, así que duplicar la
/// escritura del header de 44 bytes aquí no es un riesgo real.
///
/// Trabaja por streaming (`RandomAccessFile`) en vez de cargar el archivo
/// completo en memoria: una reunión larga puede pesar cientos de MB.
class WavChunkSplitter {
  WavChunkSplitter._();

  /// 2 minutos por fragmento para transcripción a posteriori en la nube.
  /// Deliberadamente mucho más grande que los 15s que usa la grabación en
  /// vivo (`AudioMixerService._chunkSeconds`, que responde a una necesidad
  /// distinta: cadencia de transcripción parcial en pantalla mientras se
  /// graba, no aplica aquí) y muy por debajo del límite real de OpenAI
  /// (25MB ≈ 13 min a 32KB/s con este formato: 16kHz mono 16-bit): cada
  /// fragmento se sube entero en base64 dentro del body de una única
  /// petición POST (no hay streaming), así que un fragmento de varios
  /// minutos pesaría decenas de MB en una sola petición — una interrupción
  /// de red a mitad obligaría a reenviarlo entero, justo lo que el troceo
  /// busca evitar. Con 2 min (~5MB en base64) cada subida es barata de
  /// reintentar y queda con margen amplio dentro del `pollMaxWait` del
  /// subidor de fragmentos.
  static const int defaultChunkSeconds = 120;

  static const int _headerBytes = 44;

  /// Trocea [wavFile] en archivos WAV independientes de [chunkSeconds] cada
  /// uno (el último puede ser más corto), escritos en [outputDir]. Devuelve
  /// la lista en orden. Si el archivo está vacío o el header es inválido,
  /// devuelve una lista vacía sin lanzar.
  static Future<List<File>> splitToChunks({
    required File wavFile,
    required Directory outputDir,
    int chunkSeconds = defaultChunkSeconds,
  }) async {
    final format = await _readFormat(wavFile);
    if (format == null) return const [];

    final blockAlign = format.channels * (format.bitsPerSample ~/ 8);
    if (blockAlign <= 0) return const [];
    final byteRate = format.sampleRate * blockAlign;
    var chunkBytes = byteRate * chunkSeconds;
    chunkBytes -= chunkBytes % blockAlign; // alinear a muestra completa
    if (chunkBytes <= 0) chunkBytes = blockAlign;

    await outputDir.create(recursive: true);

    final raf = await wavFile.open(mode: FileMode.read);
    try {
      await raf.setPosition(_headerBytes);
      var remaining = format.dataSize;
      final chunks = <File>[];
      var index = 0;
      while (remaining > 0) {
        final readSize = remaining < chunkBytes ? remaining : chunkBytes;
        final bytes = await raf.read(readSize);
        if (bytes.isEmpty) break; // EOF antes de lo esperado (header corrupto/truncado)
        remaining -= bytes.length;

        final chunkFile = File(
          p.join(
            outputDir.path,
            'posthoc_chunk_${index.toString().padLeft(4, '0')}.wav',
          ),
        );
        await _writeChunkFile(chunkFile, bytes, format);
        chunks.add(chunkFile);
        index++;
      }
      return chunks;
    } finally {
      await raf.close();
    }
  }

  /// Estima la duración de [wavFile] leyendo solo el header (barato). Si el
  /// `dataSize` del header parece corrupto (0, o mayor que el archivo real),
  /// cae de vuelta al tamaño real del archivo.
  static Future<Duration> estimateDuration(File wavFile) async {
    final format = await _readFormat(wavFile);
    if (format == null) return Duration.zero;
    final blockAlign = format.channels * (format.bitsPerSample ~/ 8);
    final byteRate = format.sampleRate * blockAlign;
    if (byteRate <= 0) return Duration.zero;

    var dataSize = format.dataSize;
    final fileLength = await wavFile.length();
    final maxPossible = fileLength - _headerBytes;
    if (dataSize <= 0 || dataSize > maxPossible) {
      dataSize = maxPossible > 0 ? maxPossible : 0;
    }

    final seconds = dataSize / byteRate;
    return Duration(milliseconds: (seconds * 1000).ceil());
  }

  static Future<_WavFormat?> _readFormat(File wavFile) async {
    if (!await wavFile.exists()) return null;
    final raf = await wavFile.open(mode: FileMode.read);
    try {
      final length = await raf.length();
      if (length < _headerBytes) return null;
      final header = await raf.read(_headerBytes);
      if (header.length < _headerBytes) return null;
      final bd = ByteData.sublistView(header);
      final channels = bd.getUint16(22, Endian.little);
      final sampleRate = bd.getUint32(24, Endian.little);
      final bitsPerSample = bd.getUint16(34, Endian.little);
      final dataSize = bd.getUint32(40, Endian.little);
      if (channels <= 0 || sampleRate <= 0 || bitsPerSample <= 0) return null;
      return _WavFormat(
        channels: channels,
        sampleRate: sampleRate,
        bitsPerSample: bitsPerSample,
        dataSize: dataSize,
      );
    } finally {
      await raf.close();
    }
  }

  static Future<void> _writeChunkFile(
    File file,
    Uint8List data,
    _WavFormat format,
  ) async {
    final raf = await file.open(mode: FileMode.write);
    try {
      await raf.writeFrom(_buildHeader(format, data.length));
      await raf.writeFrom(data);
    } finally {
      await raf.close();
    }
  }

  static Uint8List _buildHeader(_WavFormat format, int dataSize) {
    final header = ByteData(_headerBytes);
    // RIFF
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little); // ChunkSize
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt subchunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (PCM)
    header.setUint16(20, 1, Endian.little); // AudioFormat (PCM=1)
    header.setUint16(22, format.channels, Endian.little);
    header.setUint32(24, format.sampleRate, Endian.little);
    final blockAlign = format.channels * (format.bitsPerSample ~/ 8);
    header.setUint32(28, format.sampleRate * blockAlign, Endian.little); // ByteRate
    header.setUint16(32, blockAlign, Endian.little); // BlockAlign
    header.setUint16(34, format.bitsPerSample, Endian.little);
    // data subchunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little); // Subchunk2Size
    return header.buffer.asUint8List();
  }
}

class _WavFormat {
  const _WavFormat({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataSize,
  });

  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final int dataSize;
}
