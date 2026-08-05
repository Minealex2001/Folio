import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config_store.dart';
import '../config/models/design_variables.dart';
import 'design_tokens_defaults.dart';

/// Dueño en memoria de las [DesignVariables] activas (Fase 16) — mismo
/// patrón de mutación-inmediata + persistencia debounced que
/// `ThemeConfigController`/`LayoutEngineController`.
class DesignVariablesController extends ChangeNotifier {
  DesignVariablesController(
    this._store, {
    required DesignVariables initialConfig,
    Duration persistDebounce = const Duration(milliseconds: 400),
  }) : _config = initialConfig,
       _persistDebounce = persistDebounce;

  final ConfigStore _store;
  final Duration _persistDebounce;
  DesignVariables _config;
  Timer? _persistTimer;

  static Future<DesignVariablesController> load(
    ConfigStore store, {
    String id = 'default',
  }) async {
    final loaded = await store.loadVariables(id);
    final fallback = id == kFolioDefaultDesignVariables.id
        ? kFolioDefaultDesignVariables
        : DesignVariables(id: id);
    return DesignVariablesController(store, initialConfig: loaded ?? fallback);
  }

  DesignVariables get config => _config;

  void _update(DesignVariables next) {
    _config = next;
    notifyListeners();
    _schedulePersist();
  }

  /// Fija (o sobreescribe) el string de referencia de la variable [name] —
  /// ej. `setVariable('editorPadding', '@space.md')` o encadenando
  /// `setVariable('sidebarPadding', '@var.editorPadding')`. No valida
  /// ciclos/profundidad aquí — eso lo hace `DesignTokensResolver` en tiempo
  /// de resolución (cae al fallback en vez de lanzar).
  void setVariable(String name, String refString) {
    _update(
      _config.copyWith(entries: {..._config.entries, name: refString}),
    );
  }

  void removeVariable(String name) {
    final next = Map<String, String>.from(_config.entries)..remove(name);
    _update(_config.copyWith(entries: next));
  }

  void replaceConfig(DesignVariables next) {
    _update(DesignVariables(id: _config.id, entries: next.entries));
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, () {
      unawaited(persist());
    });
  }

  Future<void> persist() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    await _store.saveVariables(_config);
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    if (_persistTimer != null) {
      unawaited(_store.saveVariables(_config));
    }
    super.dispose();
  }
}
