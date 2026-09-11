import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config_store.dart';
import '../config/models/accessibility_config.dart';

/// Dueño en memoria del [AccessibilityConfig] activo (Fase 22) — mismo
/// patrón de mutación-inmediata + persistencia debounced que
/// `ThemeConfigController`/`LayoutEngineController`.
class AccessibilityController extends ChangeNotifier {
  AccessibilityController(
    this._store, {
    required AccessibilityConfig initialConfig,
    Duration persistDebounce = const Duration(milliseconds: 400),
  }) : _config = initialConfig,
       _persistDebounce = persistDebounce;

  final ConfigStore _store;
  final Duration _persistDebounce;
  AccessibilityConfig _config;
  Timer? _persistTimer;

  static Future<AccessibilityController> load(ConfigStore store) async {
    final loaded = await store.loadAccessibility();
    return AccessibilityController(store, initialConfig: loaded ?? AccessibilityConfig());
  }

  AccessibilityConfig get config => _config;

  void _update(AccessibilityConfig next) {
    _config = next;
    notifyListeners();
    _schedulePersist();
  }

  void setContrast(String contrast) => _update(_config.copyWith(contrast: contrast));

  void setReduceMotion(bool value) => _update(_config.copyWith(reduceMotion: value));

  void setLargeHitTargets(bool value) =>
      _update(_config.copyWith(largeHitTargets: value));

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, () {
      unawaited(persist());
    });
  }

  Future<void> persist() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    await _store.saveAccessibility(_config);
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    if (_persistTimer != null) {
      unawaited(_store.saveAccessibility(_config));
    }
    super.dispose();
  }
}
