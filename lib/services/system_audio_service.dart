import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class SystemAudioDevice {
  const SystemAudioDevice({required this.id, required this.label});

  final String id;
  final String label;

  factory SystemAudioDevice.fromMap(Map<dynamic, dynamic> map) {
    return SystemAudioDevice(
      id: '${map['id'] ?? ''}',
      label: '${map['label'] ?? ''}',
    );
  }
}

/// Servicio Dart para capturar el audio del sistema (loopback) via
/// platform channels nativos (WASAPI en Windows, ScreenCaptureKit en macOS,
/// PipeWire en Linux).
///
/// El stream emite chunks de PCM Int16LE a 16 kHz mono.
class SystemAudioService {
  SystemAudioService._();
  static final SystemAudioService instance = SystemAudioService._();

  static const _method = MethodChannel('folio/system_audio');
  static const _event = EventChannel('folio/system_audio_stream');

  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<Uint8List>.broadcast();

  /// Stream de chunks PCM Int16LE, 16 kHz, mono.
  Stream<Uint8List> get audioStream => _controller.stream;

  bool _capturing = false;
  bool get isCapturing => _capturing;

  String? _selectedDeviceId;
  String? get selectedDeviceId => _selectedDeviceId;

  Future<List<SystemAudioDevice>> listOutputDevices() async {
    try {
      final raw = await _method.invokeMethod<List<dynamic>>('listDevices');
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(SystemAudioDevice.fromMap)
          .where((d) => d.id.trim().isNotEmpty)
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  void selectOutputDevice(String? deviceId) {
    final t = deviceId?.trim();
    _selectedDeviceId = (t == null || t.isEmpty) ? null : t;
  }

  /// Inicia la captura de audio del sistema.
  /// En macOS solicita permiso de Screen Recording si es necesario.
  Future<bool> startCapture({String? deviceId}) async {
    if (_capturing) return true;
    try {
      final target = (deviceId?.trim().isNotEmpty == true)
          ? deviceId!.trim()
          : _selectedDeviceId;
      final ok = await _method.invokeMethod<bool>('startCapture', {
            if (target != null && target.isNotEmpty) 'deviceId': target,
          }) ??
          false;
      if (!ok) return false;

      _sub = _event.receiveBroadcastStream().listen((data) {
        if (data is Uint8List) {
          _controller.add(data);
        } else if (data is List) {
          _controller.add(Uint8List.fromList(data.cast<int>()));
        }
      });
      _capturing = true;
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Plataforma no soportada — el audio del sistema no está disponible
      return false;
    }
  }

  Future<void> stopCapture() async {
    if (!_capturing) return;
    await _sub?.cancel();
    _sub = null;
    try {
      await _method.invokeMethod('stopCapture');
    } on PlatformException catch (_) {
      // Ignorar errores al detener
    }
    _capturing = false;
  }

  /// Devuelve true si audio del sistema está soportado en esta plataforma.
  static bool get isSupported =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
}
