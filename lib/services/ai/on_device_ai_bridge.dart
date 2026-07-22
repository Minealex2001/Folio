import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

/// Fabricante normalizado para etiquetar el proveedor on-device.
enum OnDeviceAiBrand { google, samsung, other }

/// Estado de Gemini Nano / AICore en el dispositivo.
enum OnDeviceAiStatus {
  available,
  downloadable,
  downloading,
  unavailable,
}

/// Progreso de descarga del modelo on-device.
class OnDeviceAiDownloadEvent {
  const OnDeviceAiDownloadEvent({
    required this.phase,
    this.bytesDownloaded,
    this.bytesToDownload,
    this.message,
  });

  final String phase;
  final int? bytesDownloaded;
  final int? bytesToDownload;
  final String? message;
}

/// Cliente MethodChannel → ML Kit GenAI Prompt (Gemini Nano vía AICore).
class OnDeviceAiBridge {
  OnDeviceAiBridge._();

  static const _channel = MethodChannel('com.minealexgames.folio/on_device_ai');
  static const _downloadEvents = EventChannel(
    'com.minealexgames.folio/on_device_ai_download',
  );

  static OnDeviceAiBrand? _cachedBrand;
  static OnDeviceAiStatus? _cachedStatus;

  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Marca cacheada (o [OnDeviceAiBrand.other] si aún no se resolvió).
  static OnDeviceAiBrand get cachedBrandOrDefault =>
      _cachedBrand ?? OnDeviceAiBrand.other;

  static OnDeviceAiStatus? get cachedStatus => _cachedStatus;

  static Future<OnDeviceAiBrand> getDeviceBrand({bool force = false}) async {
    if (!force && _cachedBrand != null) return _cachedBrand!;
    if (!isSupportedPlatform) {
      _cachedBrand = OnDeviceAiBrand.other;
      return _cachedBrand!;
    }
    try {
      final raw = await _channel.invokeMethod<String>('getDeviceBrand');
      _cachedBrand = _parseBrand(raw);
    } on MissingPluginException {
      _cachedBrand = OnDeviceAiBrand.other;
    } on PlatformException {
      _cachedBrand = OnDeviceAiBrand.other;
    }
    return _cachedBrand!;
  }

  static Future<OnDeviceAiStatus> checkStatus({bool force = false}) async {
    if (!force && _cachedStatus != null) return _cachedStatus!;
    if (!isSupportedPlatform) {
      _cachedStatus = OnDeviceAiStatus.unavailable;
      return _cachedStatus!;
    }
    try {
      final raw = await _channel.invokeMethod<String>('checkStatus');
      _cachedStatus = _parseStatus(raw);
    } on MissingPluginException {
      _cachedStatus = OnDeviceAiStatus.unavailable;
    } on PlatformException {
      _cachedStatus = OnDeviceAiStatus.unavailable;
    }
    return _cachedStatus!;
  }

  static Future<void> ping() async {
    if (!isSupportedPlatform) {
      throw StateError('On-device AI is only available on Android');
    }
    try {
      await _channel.invokeMethod<String>('ping');
      _cachedStatus = OnDeviceAiStatus.available;
    } on PlatformException catch (e) {
      final details = e.details;
      if (details is Map && details['status'] is String) {
        _cachedStatus = _parseStatus(details['status'] as String);
      }
      rethrow;
    }
  }

  static Future<OnDeviceAiStatus> download() async {
    if (!isSupportedPlatform) {
      throw StateError('On-device AI is only available on Android');
    }
    final raw = await _channel.invokeMethod<String>('download');
    _cachedStatus = _parseStatus(raw ?? 'available');
    return _cachedStatus!;
  }

  static Stream<OnDeviceAiDownloadEvent> downloadEvents() {
    if (!isSupportedPlatform) {
      return const Stream.empty();
    }
    return _downloadEvents.receiveBroadcastStream().map((event) {
      final map = event is Map
          ? Map<String, dynamic>.from(event)
          : <String, dynamic>{};
      return OnDeviceAiDownloadEvent(
        phase: '${map['phase'] ?? ''}',
        bytesDownloaded: _asInt(map['bytesDownloaded']),
        bytesToDownload: _asInt(map['bytesToDownload']),
        message: map['message']?.toString(),
      );
    });
  }

  static Future<String> generateContent(String prompt) async {
    if (!isSupportedPlatform) {
      throw StateError('On-device AI is only available on Android');
    }
    final text = await _channel.invokeMethod<String>(
      'generateContent',
      <String, dynamic>{'prompt': prompt},
    );
    final trimmed = (text ?? '').trim();
    if (trimmed.isEmpty) {
      throw StateError('Gemini Nano returned empty text');
    }
    return trimmed;
  }

  static OnDeviceAiBrand _parseBrand(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'samsung':
        return OnDeviceAiBrand.samsung;
      case 'google':
        return OnDeviceAiBrand.google;
      default:
        return OnDeviceAiBrand.other;
    }
  }

  static OnDeviceAiStatus _parseStatus(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'available':
        return OnDeviceAiStatus.available;
      case 'downloadable':
        return OnDeviceAiStatus.downloadable;
      case 'downloading':
        return OnDeviceAiStatus.downloading;
      default:
        return OnDeviceAiStatus.unavailable;
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
