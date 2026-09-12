import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Estado del dispositivo Spotify Connect local que aloja Folio (Web
/// Playback SDK).
enum SpotifyLocalDeviceStatus {
  /// El usuario no ha activado el toggle "Usar Folio como dispositivo".
  disabled,

  /// Activado, pero la plataforma actual no soporta el Web Playback SDK
  /// (p.ej. Linux, sin WebView con EME/Widevine fiable).
  unsupported,

  /// Activado y soportado, esperando a que el SDK conecte.
  connecting,

  /// El SDK está conectado y `deviceId` es válido: Folio ya aparece como
  /// dispositivo Spotify Connect.
  ready,

  /// El SDK reportó un error (cuenta no Premium, token inválido, etc.).
  error,
}

/// Puente entre el host de WebView/JS por plataforma (que emite eventos del
/// SDK) y el resto de la app (que solo necesita saber si Folio está listo
/// como dispositivo y cuál es su `deviceId`).
class SpotifyLocalDeviceService extends ChangeNotifier {
  SpotifyLocalDeviceService._();
  static final SpotifyLocalDeviceService instance = SpotifyLocalDeviceService._();

  SpotifyLocalDeviceStatus _status = SpotifyLocalDeviceStatus.disabled;
  String? _deviceId;
  String? _lastError;
  bool _enabled = false;
  Future<String?> Function()? _tokenProvider;

  SpotifyLocalDeviceStatus get status => _status;
  String? get deviceId => _deviceId;
  String? get lastError => _lastError;
  bool get enabled => _enabled;
  bool get isReady =>
      _status == SpotifyLocalDeviceStatus.ready && _deviceId != null;
  Future<String?> Function()? get tokenProvider => _tokenProvider;

  /// Activa o desactiva el dispositivo local. [tokenProvider] debe devolver
  /// un access token de Spotify vigente (refrescándolo si hace falta); el
  /// host de plataforma lo llama periódicamente para alimentar al SDK JS.
  void configure({
    required bool enabled,
    required bool platformSupported,
    Future<String?> Function()? tokenProvider,
  }) {
    _tokenProvider = tokenProvider;
    final effectiveEnabled = enabled && platformSupported;
    if (_enabled == effectiveEnabled &&
        (_status != SpotifyLocalDeviceStatus.disabled || !effectiveEnabled)) {
      // Sin cambio de intención real; evita resets innecesarios del estado.
      if (!enabled) {
        _reset(SpotifyLocalDeviceStatus.disabled);
      } else if (!platformSupported) {
        _reset(SpotifyLocalDeviceStatus.unsupported);
      }
      return;
    }
    _enabled = effectiveEnabled;
    if (!enabled) {
      _reset(SpotifyLocalDeviceStatus.disabled);
    } else if (!platformSupported) {
      _reset(SpotifyLocalDeviceStatus.unsupported);
    } else {
      _status = SpotifyLocalDeviceStatus.connecting;
      _lastError = null;
      notifyListeners();
    }
  }

  void _reset(SpotifyLocalDeviceStatus status) {
    _status = status;
    _deviceId = null;
    _lastError = null;
    notifyListeners();
  }

  /// Llamado por el host de plataforma cuando llega un mensaje crudo del
  /// puente JS (`{"type": "...", "payload": {...}}`).
  void handleBridgeMessage(String raw) {
    Map<String, dynamic>? map;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) map = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    if (map == null) return;
    final type = (map['type'] as String? ?? '').trim();
    final payload = map['payload'];
    final payloadMap = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    switch (type) {
      case 'ready':
        final id = (payloadMap['device_id'] as String? ?? '').trim();
        if (id.isNotEmpty) _reportReady(id);
        break;
      case 'not_ready':
        _reportNotReady();
        break;
      case 'initialization_error':
      case 'authentication_error':
      case 'account_error':
      case 'playback_error':
        _reportError(type, (payloadMap['message'] as String? ?? '').trim());
        break;
    }
  }

  void _reportReady(String deviceId) {
    _deviceId = deviceId;
    _status = SpotifyLocalDeviceStatus.ready;
    _lastError = null;
    notifyListeners();
  }

  void _reportNotReady() {
    _deviceId = null;
    if (_enabled) {
      _status = SpotifyLocalDeviceStatus.connecting;
    }
    notifyListeners();
  }

  void _reportError(String code, String message) {
    _deviceId = null;
    _status = SpotifyLocalDeviceStatus.error;
    _lastError = message.isEmpty ? code : '$code: $message';
    notifyListeners();
  }
}
