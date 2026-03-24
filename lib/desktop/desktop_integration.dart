import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app/app_settings.dart';

typedef VoidAsyncCallback = Future<void> Function();

class DesktopTrayLabels {
  const DesktopTrayLabels({
    required this.open,
    required this.search,
    required this.lock,
    required this.exit,
  });

  final String open;
  final String search;
  final String lock;
  final String exit;
}

class DesktopIntegration with TrayListener, WindowListener {
  DesktopIntegration({
    required this.settings,
    required this.onOpenRequested,
    required this.onSearchRequested,
    required this.onLockRequested,
    required this.onExitRequested,
    required this.labelsBuilder,
  });

  final AppSettings settings;
  final VoidAsyncCallback onOpenRequested;
  final VoidAsyncCallback onSearchRequested;
  final VoidAsyncCallback onLockRequested;
  final VoidAsyncCallback onExitRequested;
  final DesktopTrayLabels Function() labelsBuilder;

  HotKey? _searchHotKey;
  var _initialized = false;
  var _quitting = false;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> initialize() async {
    if (_initialized || !_isDesktop) return;
    _initialized = true;
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    trayManager.addListener(this);
    await _setupTray();
    await applySettings();
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await hotKeyManager.unregisterAll();
  }

  Future<void> applySettings() async {
    if (!_initialized) return;
    await _setupTray();
    await _registerHotkey();
  }

  Future<void> _setupTray() async {
    try {
      await trayManager.setIcon('assets/icons/folio.ico');
    } catch (_) {}
    await trayManager.setToolTip('Folio');
    final labels = labelsBuilder();
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'open', label: labels.open),
          MenuItem(key: 'search', label: labels.search),
          MenuItem.separator(),
          MenuItem(key: 'lock', label: labels.lock),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: labels.exit),
        ],
      ),
    );
  }

  Future<void> _registerHotkey() async {
    if (_searchHotKey != null) {
      await hotKeyManager.unregister(_searchHotKey!);
      _searchHotKey = null;
    }
    if (!settings.enableGlobalSearchHotkey) return;
    final preferred = settings.globalSearchHotkey;
    final candidates = <String>[
      preferred,
      if (preferred.toLowerCase() != 'ctrl+shift+k') 'Ctrl+Shift+K',
      if (preferred.toLowerCase() != 'ctrl+shift+space') 'Ctrl+Shift+Space',
      if (preferred.toLowerCase() != 'alt+space') 'Alt+Space',
    ];
    for (final combo in candidates) {
      final key = _parseHotkey(combo);
      if (key == null) continue;
      try {
        await hotKeyManager.register(
          key,
          keyDownHandler: (_) async {
            await onSearchRequested();
          },
        );
        _searchHotKey = key;
        break;
      } catch (_) {
        continue;
      }
    }
  }

  HotKey? _parseHotkey(String raw) {
    final t = raw.trim().toLowerCase();
    if (t == 'alt+space') {
      return HotKey(
        key: PhysicalKeyboardKey.space,
        modifiers: [HotKeyModifier.alt],
        scope: HotKeyScope.system,
      );
    }
    if (t == 'ctrl+shift+space') {
      return HotKey(
        key: PhysicalKeyboardKey.space,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
    }
    if (t == 'ctrl+shift+k') {
      return HotKey(
        key: PhysicalKeyboardKey.keyK,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
    }
    if (t == 'ctrl+shift+f') {
      return HotKey(
        key: PhysicalKeyboardKey.keyF,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
    }
    if (t == 'ctrl+alt+space') {
      return HotKey(
        key: PhysicalKeyboardKey.space,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      );
    }
    return null;
  }

  Future<void> showAndFocus() async {
    if (!_isDesktop) return;
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideToTray() async {
    if (!_isDesktop) return;
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    onOpenRequested();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        onOpenRequested();
        break;
      case 'search':
        onSearchRequested();
        break;
      case 'lock':
        onLockRequested();
        break;
      case 'exit':
        _quitting = true;
        onExitRequested();
        unawaited(windowManager.destroy());
        break;
    }
  }

  @override
  Future<void> onWindowClose() async {
    if (_quitting) return;
    if (settings.closeToTray) {
      await hideToTray();
      return;
    }
    _quitting = true;
    await onExitRequested();
    await windowManager.destroy();
  }
}
