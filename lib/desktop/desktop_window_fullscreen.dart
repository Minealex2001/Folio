import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Pantalla completa de la ventana OS en escritorio (Windows / macOS / Linux).
///
/// No-op en web y móviles. Escucha cambios nativos (p. ej. Escape) vía
/// [WindowListener] para sincronizar UI sin acoplar a [DesktopIntegration].
class DesktopWindowFullscreen with WindowListener {
  DesktopWindowFullscreen._();

  static final DesktopWindowFullscreen instance = DesktopWindowFullscreen._();

  final List<void Function(bool fullScreen)> _listeners = [];
  var _listening = false;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Registra un listener de cambios de fullscreen (entrada/salida nativa).
  void addListener(void Function(bool fullScreen) listener) {
    _listeners.add(listener);
    _ensureListening();
  }

  void removeListener(void Function(bool fullScreen) listener) {
    _listeners.remove(listener);
    if (_listeners.isEmpty && _listening) {
      windowManager.removeListener(this);
      _listening = false;
    }
  }

  void _ensureListening() {
    if (!_isDesktop || _listening) return;
    windowManager.addListener(this);
    _listening = true;
  }

  void _notify(bool fullScreen) {
    for (final listener in List.of(_listeners)) {
      listener(fullScreen);
    }
  }

  Future<bool> isFullScreen() async {
    if (!_isDesktop) return false;
    try {
      return await windowManager.isFullScreen();
    } catch (_) {
      return false;
    }
  }

  Future<void> setFullScreen(bool value) async {
    if (!_isDesktop) return;
    try {
      await windowManager.setFullScreen(value);
    } catch (_) {}
  }

  @override
  void onWindowEnterFullScreen() => _notify(true);

  @override
  void onWindowLeaveFullScreen() => _notify(false);
}
