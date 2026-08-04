import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Axis;

import '../config/config_store.dart';
import '../config/models/layout_config.dart';
import '../config/models/panel_config.dart';

/// Dueño en memoria del [LayoutConfig] activo. Traduce gestos de drag/resize
/// (deltas por frame, a 60fps) en mutaciones de `PanelConfig`, notificando
/// solo a quien escucha la región afectada (vía [listenable]) en vez de
/// reconstruir todo el shell en cada pixel arrastrado.
///
/// La escritura a disco (`ConfigStore.saveLayout`) se hace con debounce —
/// un gesto de arrastre dispara muchas mutaciones en memoria, pero solo una
/// escritura a disco ~400ms después del último cambio.
class LayoutEngineController extends ChangeNotifier {
  LayoutEngineController(
    this._store, {
    required LayoutConfig initialConfig,
    Duration persistDebounce = const Duration(milliseconds: 400),
  }) : _config = initialConfig,
       _persistDebounce = persistDebounce {
    for (final entry in _config.panels.entries) {
      _regionNotifiers[entry.key] = ValueNotifier<PanelConfig>(entry.value);
    }
  }

  final ConfigStore _store;
  final Duration _persistDebounce;
  LayoutConfig _config;
  Timer? _persistTimer;

  final Map<String, ValueNotifier<PanelConfig>> _regionNotifiers = {};

  /// Carga el [LayoutConfig] con [id] desde [store] (o `defaultConfig()` si
  /// no existe todavía) y construye el controller.
  static Future<LayoutEngineController> load(
    ConfigStore store, {
    required String id,
  }) async {
    final loaded = await store.loadLayout(id);
    return LayoutEngineController(
      store,
      initialConfig: loaded ?? LayoutConfig.defaultConfig(id: id),
    );
  }

  LayoutConfig get config => _config;

  PanelConfig? panelFor(String regionId) => _config.panels[regionId];

  /// `ValueListenable` de una región concreta — usar con `ValueListenableBuilder`
  /// para que arrastrar/redimensionar un panel no reconstruya el resto del
  /// shell. Devuelve un notifier "vacío" si la región no existe todavía (para
  /// que llamarlo antes de que el layout tenga esa región no lance).
  ValueListenable<PanelConfig?> listenable(String regionId) {
    final existing = _regionNotifiers[regionId];
    if (existing != null) return existing;
    final fresh = ValueNotifier<PanelConfig?>(_config.panels[regionId]);
    // No lo guardamos en _regionNotifiers (que es <String, PanelConfig> no
    // nullable) — este camino solo cubre "región inexistente" de forma segura.
    return fresh;
  }

  void _setPanel(String regionId, PanelConfig next) {
    _config = _config.copyWith(panels: {..._config.panels, regionId: next});
    final notifier = _regionNotifiers.putIfAbsent(
      regionId,
      () => ValueNotifier<PanelConfig>(next),
    );
    notifier.value = next;
    notifyListeners();
    _schedulePersist();
  }

  void setVisible(String regionId, bool visible) {
    final panel = panelFor(regionId);
    if (panel == null || panel.visible == visible) return;
    _setPanel(regionId, panel.copyWith(visible: visible));
  }

  void setSize(String regionId, {double? width, double? height}) {
    final panel = panelFor(regionId);
    if (panel == null) return;
    _setPanel(regionId, panel.copyWith(width: width, height: height));
  }

  void resizeByDelta(String regionId, double delta, {Axis axis = Axis.horizontal}) {
    final panel = panelFor(regionId);
    if (panel == null || panel.locked) return;
    if (axis == Axis.horizontal) {
      final next = (panel.width ?? 0) + delta;
      _setPanel(regionId, panel.copyWith(width: next));
    } else {
      final next = (panel.height ?? 0) + delta;
      _setPanel(regionId, panel.copyWith(height: next));
    }
  }

  void setLocked(String regionId, bool locked) {
    final panel = panelFor(regionId);
    if (panel == null || panel.locked == locked) return;
    _setPanel(regionId, panel.copyWith(locked: locked));
  }

  void setFloatingPosition(String regionId, double x, double y) {
    final panel = panelFor(regionId);
    if (panel == null || panel.locked) return;
    _setPanel(regionId, panel.copyWith(floatingX: x, floatingY: y));
  }

  void reorderPanel(String regionId, int newOrder) {
    final panel = panelFor(regionId);
    if (panel == null) return;
    _setPanel(regionId, panel.copyWith(order: newOrder));
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
    await _store.saveLayout(_config);
  }

  Future<void> saveAsPreset(String id, String name) async {
    final preset = _config.copyWith(name: name);
    await _store.saveLayout(
      LayoutConfig(
        id: id,
        name: name,
        panels: preset.panels,
        responsiveOverrides: preset.responsiveOverrides,
      ),
    );
  }

  Future<void> loadPreset(String id) async {
    final loaded = await _store.loadLayout(id);
    if (loaded == null) return;
    // Adopta paneles/nombre del preset pero conserva la id del layout activo
    // (LayoutConfig.copyWith no permite cambiar `id`: es inmutable por diseño).
    _config = LayoutConfig(
      id: _config.id,
      name: loaded.name,
      panels: loaded.panels,
      responsiveOverrides: loaded.responsiveOverrides,
    );
    for (final entry in _config.panels.entries) {
      final notifier = _regionNotifiers.putIfAbsent(
        entry.key,
        () => ValueNotifier<PanelConfig>(entry.value),
      );
      notifier.value = entry.value;
    }
    notifyListeners();
    _schedulePersist();
  }

  /// Restablece el layout activo a los valores por defecto (misma id, sin
  /// tocar otros presets guardados).
  Future<void> resetToDefault() async {
    final fresh = LayoutConfig.defaultConfig(id: _config.id);
    _config = fresh;
    for (final entry in fresh.panels.entries) {
      final notifier = _regionNotifiers.putIfAbsent(
        entry.key,
        () => ValueNotifier<PanelConfig>(entry.value),
      );
      notifier.value = entry.value;
    }
    notifyListeners();
    await persist();
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    // Flush best-effort: no podemos await dentro de dispose(), pero si hay
    // un cambio pendiente sin persistir, lo disparamos igual (fire-and-forget)
    // en vez de perderlo silenciosamente.
    if (_persistTimer != null) {
      unawaited(_store.saveLayout(_config));
    }
    for (final notifier in _regionNotifiers.values) {
      notifier.dispose();
    }
    super.dispose();
  }
}
