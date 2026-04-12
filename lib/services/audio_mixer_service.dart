import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'system_audio_service.dart';

/// Mezcla PCM del micrófono y del audio del sistema, escribe el WAV mezclado
/// en disco y emite chunks de ~15 s para transcripción.
class AudioMixerService {
  AudioMixerService._();
  static final AudioMixerService instance = AudioMixerService._();

  static const int _sampleRate = 16000;
  static const int _chunkSeconds = 15;
  static const int _chunkSamples = _sampleRate * _chunkSeconds; // 240 000

  final _record = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<Uint8List>? _sysSub;

  // Buffers de muestra pendientes de mezcla
  final List<int> _micBuf = [];
  final List<int> _sysBuf = [];

  // Acumulador de samples mezclados para el chunk actual
  final List<int> _chunkSamples_ = [];

  // Archivo WAV activo (audio completo de la sesión)
  RandomAccessFile? _wavRaf;
  String? _wavTempPath;
  int _wavDataBytes = 0;

  bool _active = false;
  bool get isActive => _active;

  // Stream de chunks para transcripción
  final _chunkController = StreamController<File>.broadcast();
  Stream<File> get chunkStream => _chunkController.stream;

  /// Inicia la grabación mixta. Devuelve false si el micrófono no está disponible.
  Future<bool> start({
    InputDevice? micDevice,
    String? micDeviceId,
    String? systemOutputDeviceId,
  }) async {
    if (_active) return true;

    final hasPermission = await _record.hasPermission();
    if (!hasPermission) return false;

    InputDevice? selectedMicDevice = micDevice;
    final desiredMicId = micDeviceId?.trim() ?? '';
    if (selectedMicDevice == null && desiredMicId.isNotEmpty) {
      try {
        final devices = await _record.listInputDevices();
        for (final d in devices) {
          if (d.id == desiredMicId) {
            selectedMicDevice = d;
            break;
          }
        }
      } catch (_) {
        // Si falla la enumeracion, se usa el dispositivo por defecto.
      }
    }

    final tempDir = await getTemporaryDirectory();
    _wavTempPath = p.join(tempDir.path, 'folio_meeting_active.wav');
    _wavDataBytes = 0;

    final raf = File(_wavTempPath!).openSync(mode: FileMode.write);
    _wavRaf = raf;
    _writeWavHeader(raf, 0); // placeholder, se actualizará al parar

    // Micrófono — stream PCM Int16LE 16kHz mono
    final micStream = await _record.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        device: selectedMicDevice,
      ),
    );
    _micSub = micStream.listen(_onMicData);

    // Audio del sistema
    final sysOk = await SystemAudioService.instance.startCapture(
      deviceId: systemOutputDeviceId,
    );
    if (sysOk) {
      _sysSub = SystemAudioService.instance.audioStream.listen(_onSysData);
    }

    _active = true;
    return true;
  }

  /// Detiene la grabación y devuelve la ruta del archivo WAV completo.
  /// Mueve el archivo temporal a [destDir]/[filename].
  Future<File?> stop({required String destPath}) async {
    if (!_active) return null;
    _active = false;

    await _micSub?.cancel();
    _micSub = null;
    await _sysSub?.cancel();
    _sysSub = null;

    await _record.stop();
    await SystemAudioService.instance.stopCapture();

    // Mezclar samples restantes
    _flushRemaining();

    // Finalizar WAV
    if (_wavRaf != null) {
      _finalizeWav(_wavRaf!, _wavDataBytes);
      _wavRaf!.closeSync();
      _wavRaf = null;
    }

    if (_wavTempPath == null) return null;

    final dest = File(destPath);
    await dest.parent.create(recursive: true);
    await File(_wavTempPath!).rename(destPath);
    _wavTempPath = null;

    // Limpiar estado
    _micBuf.clear();
    _sysBuf.clear();
    _chunkSamples_.clear();
    _wavDataBytes = 0;

    return dest;
  }

  // ───────────── handlers de datos PCM

  void _onMicData(Uint8List data) {
    _micBuf.addAll(data);
    _tryMix();
  }

  void _onSysData(Uint8List data) {
    _sysBuf.addAll(data);
    _tryMix();
  }

  void _tryMix() {
    // Siempre priorizamos avance del micrófono. Si no hay muestra del sistema,
    // mezclamos con cero para evitar bloquear el pipeline.
    while (_micBuf.length >= 2) {
      final micLo = _micBuf.removeAt(0);
      final micHi = _micBuf.removeAt(0);
      int micSample = (micHi << 8) | micLo;
      if (micSample > 32767) micSample -= 65536; // sign extend

      int mixed;
      if (_sysBuf.length >= 2) {
        final sysLo = _sysBuf.removeAt(0);
        final sysHi = _sysBuf.removeAt(0);
        int sysSample = (sysHi << 8) | sysLo;
        if (sysSample > 32767) sysSample -= 65536;
        mixed = (micSample + sysSample).clamp(-32768, 32767);
      } else {
        mixed = micSample;
      }

      // Escribir al WAV
      final lo = mixed & 0xFF;
      final hi = (mixed >> 8) & 0xFF;
      _wavRaf?.writeByteSync(lo);
      _wavRaf?.writeByteSync(hi);
      _wavDataBytes += 2;

      // Acumular para el chunk de transcripción
      _chunkSamples_.add(lo);
      _chunkSamples_.add(hi);

      if (_chunkSamples_.length >= _chunkSamples * 2) {
        _emitChunk();
      }
    }
  }

  void _flushRemaining() {
    // Vaciar micBuf sin sistema
    while (_micBuf.length >= 2) {
      final lo = _micBuf.removeAt(0);
      final hi = _micBuf.removeAt(0);
      _wavRaf?.writeByteSync(lo);
      _wavRaf?.writeByteSync(hi);
      _wavDataBytes += 2;
      _chunkSamples_.add(lo);
      _chunkSamples_.add(hi);
    }
    if (_chunkSamples_.isNotEmpty) {
      _emitChunk();
    }
  }

  Future<void> _emitChunk() async {
    if (_chunkSamples_.isEmpty) return;
    final pcm = Uint8List.fromList(List.unmodifiable(_chunkSamples_));
    _chunkSamples_.clear();

    final tempDir = await getTemporaryDirectory();
    final chunkPath = p.join(
      tempDir.path,
      'folio_chunk_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    final chunkFile = File(chunkPath);
    final raf = chunkFile.openSync(mode: FileMode.write);
    _writeWavHeader(raf, pcm.length);
    raf.writeFromSync(pcm);
    _finalizeWav(raf, pcm.length);
    raf.closeSync();

    _chunkController.add(chunkFile);
  }

  // ───────────── WAV header helpers

  /// Escribe un header WAV con [dataSize] bytes de datos PCM Int16 16kHz mono.
  void _writeWavHeader(RandomAccessFile raf, int dataSize) {
    final header = ByteData(44);
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
    header.setUint16(22, 1, Endian.little); // NumChannels (mono)
    header.setUint32(24, _sampleRate, Endian.little); // SampleRate
    header.setUint32(28, _sampleRate * 2, Endian.little); // ByteRate
    header.setUint16(32, 2, Endian.little); // BlockAlign
    header.setUint16(34, 16, Endian.little); // BitsPerSample
    // data subchunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little); // Subchunk2Size
    raf.setPositionSync(0);
    raf.writeFromSync(header.buffer.asUint8List());
  }

  /// Sobreescribe los campos de tamaño en el header una vez conocemos el tamaño total.
  void _finalizeWav(RandomAccessFile raf, int dataSize) {
    raf.setPositionSync(4);
    final chunkSize = ByteData(4);
    chunkSize.setUint32(0, 36 + dataSize, Endian.little);
    raf.writeFromSync(chunkSize.buffer.asUint8List());

    raf.setPositionSync(40);
    final dataChunkSize = ByteData(4);
    dataChunkSize.setUint32(0, dataSize, Endian.little);
    raf.writeFromSync(dataChunkSize.buffer.asUint8List());
  }
}
