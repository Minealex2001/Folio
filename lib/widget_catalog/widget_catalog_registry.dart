import 'package:flutter/foundation.dart';

import 'folio_widget_plugin.dart';

/// Registro global de plugins de widget instalados. Un plugin nuevo es un
/// archivo + una llamada a [register] en el bootstrap — nunca requiere
/// modificar `workspace_home_view.dart`, `PanelHost` ni el motor de layout.
class WidgetCatalogRegistry {
  WidgetCatalogRegistry._();

  static final WidgetCatalogRegistry instance = WidgetCatalogRegistry._();

  final Map<String, FolioWidgetPlugin> _plugins = {};

  /// Registra [plugin]. En debug, lanza si ya existe un plugin con el mismo
  /// [FolioWidgetPlugin.id] — una colisión de id es un bug de quien registra,
  /// mejor detectarlo temprano que dejar que el último gane en silencio.
  void register(FolioWidgetPlugin plugin) {
    assert(
      !_plugins.containsKey(plugin.id),
      'WidgetCatalogRegistry: ya existe un plugin registrado con id '
      '"${plugin.id}" (${_plugins[plugin.id]?.runtimeType}). '
      'Intentando registrar: ${plugin.runtimeType}.',
    );
    _plugins[plugin.id] = plugin;
  }

  FolioWidgetPlugin? operator [](String id) => _plugins[id];

  List<FolioWidgetPlugin> get all => List.unmodifiable(_plugins.values);

  @visibleForTesting
  void debugClear() => _plugins.clear();
}
