import 'package:flutter/foundation.dart';

import '../config/config_store.dart';

/// Dueño en memoria de "qué pack visual está activo" — puramente
/// informativo (para que Settings pueda resaltar el pack aplicado); el
/// contenido real de un pack se aplica directamente a
/// `LayoutEngineController`/`ThemeConfigController`/`DashboardGridController`
/// vía `VisualPackInstaller`, no a través de este controller.
class ActivePackController extends ChangeNotifier {
  ActivePackController(this._store, {String? initialPackId})
    : _activePackId = initialPackId;

  final ConfigStore _store;
  String? _activePackId;

  String? get activePackId => _activePackId;

  static Future<ActivePackController> load(ConfigStore store) async {
    final id = await store.loadActivePackId();
    return ActivePackController(store, initialPackId: id);
  }

  Future<void> setActivePackId(String? packId) async {
    _activePackId = packId;
    notifyListeners();
    await _store.saveActivePackId(packId);
  }
}
