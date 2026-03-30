import 'dart:io';

import 'package:flutter/services.dart';

class AndroidMulticastLock {
  static const MethodChannel _channel = MethodChannel('dev.folio.app/network');

  static Future<void> acquire() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('acquireMulticastLock');
    } catch (_) {
      // Si falla, la sincronizacion puede seguir intentando descubrir peers.
    }
  }

  static Future<void> release() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('releaseMulticastLock');
    } catch (_) {
      // Evita romper el cierre del controlador por un error de plataforma.
    }
  }
}
