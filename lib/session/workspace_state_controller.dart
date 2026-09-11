import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../config/config_store.dart';
import '../config/models/workspace_config.dart';

/// Dueño en memoria del [WorkspaceConfig] activo (Fase 28) — mismo patrón
/// de mutación-inmediata + persistencia debounced que
/// `ThemeConfigController`/`LayoutEngineController`/`AccessibilityController`.
class WorkspaceStateController extends ChangeNotifier {
  WorkspaceStateController(
    this._store, {
    required WorkspaceConfig initialConfig,
    Duration persistDebounce = const Duration(milliseconds: 400),
  }) : _config = initialConfig,
       _persistDebounce = persistDebounce;

  final ConfigStore _store;
  final Duration _persistDebounce;
  WorkspaceConfig _config;
  Timer? _persistTimer;

  static Future<WorkspaceStateController> load(ConfigStore store) async {
    final loaded = await store.loadWorkspaceState();
    return WorkspaceStateController(
      store,
      initialConfig: loaded ?? const WorkspaceConfig(),
    );
  }

  WorkspaceConfig get config => _config;

  void _update(WorkspaceConfig next) {
    _config = next;
    notifyListeners();
    _schedulePersist();
  }

  void setFocusMode(bool value) => _update(_config.copyWith(focusMode: value));

  void setActiveDashboardId(String id) =>
      _update(_config.copyWith(activeDashboardId: id));

  void setZoom(double value) => _update(_config.copyWith(zoom: value));

  void setAiPanelOpen(bool value) => _update(_config.copyWith(aiPanelOpen: value));

  void setCollabPanelOpen(bool value) =>
      _update(_config.copyWith(collabPanelOpen: value));

  void setActivePageId(String? pageId) => _update(
    _config.copyWith(activePageId: pageId, clearActivePageId: pageId == null),
  );

  void togglePinnedPage(String pageId) {
    final pinned = List<String>.from(_config.pinnedPageIds);
    if (pinned.contains(pageId)) {
      pinned.remove(pageId);
    } else {
      pinned.add(pageId);
    }
    _update(_config.copyWith(pinnedPageIds: pinned));
  }

  // ── Pestañas (Fase 29 construye la UI sobre estos métodos) ───────────

  void openTab(String pageId) {
    if (_config.openTabs.any((t) => t.pageId == pageId)) {
      _update(_config.copyWith(activeTabId: pageId));
      return;
    }
    final next = [
      ..._config.openTabs,
      WorkspaceTabEntry(pageId: pageId, order: _config.openTabs.length),
    ];
    _update(_config.copyWith(openTabs: next, activeTabId: pageId));
  }

  void closeTab(String pageId) {
    final next = _config.openTabs.where((t) => t.pageId != pageId).toList();
    final wasActive = _config.activeTabId == pageId;
    _update(
      _config.copyWith(
        openTabs: next,
        activeTabId: wasActive ? next.lastOrNull?.pageId : null,
        clearActiveTabId: wasActive && next.isEmpty,
      ),
    );
  }

  void setTabPinned(String pageId, bool pinned) {
    final next = [
      for (final t in _config.openTabs)
        if (t.pageId == pageId) t.copyWith(pinned: pinned) else t,
    ];
    _update(_config.copyWith(openTabs: next));
  }

  void activateTab(String pageId) {
    if (!_config.openTabs.any((t) => t.pageId == pageId)) return;
    _update(_config.copyWith(activeTabId: pageId));
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
    await _store.saveWorkspaceState(_config);
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    if (_persistTimer != null) {
      unawaited(_store.saveWorkspaceState(_config));
    }
    super.dispose();
  }
}
