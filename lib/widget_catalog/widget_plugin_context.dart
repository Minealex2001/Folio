import '../app/app_settings.dart';
import '../config/config_store.dart';

/// Superficie de capacidad que un [FolioWidgetPlugin] recibe al construirse
/// — deliberadamente angosta (no la app/router completos): un plugin puede
/// leer settings/config, pero no navegar ni tocar el core del shell. Ver
/// Fase 4 del plan de personalización — "añadir un widget nunca toca el
/// core" solo se sostiene si los plugins no tienen acceso libre.
class WidgetPluginContext {
  const WidgetPluginContext({required this.appSettings, required this.configStore});

  /// Todavía necesario para cosas transversales no migradas a [ConfigStore]
  /// (tokens de auth, feature flags, etc.).
  final AppSettings appSettings;
  final ConfigStore configStore;
}

/// Restricciones de tamaño de un widget en unidades de grid del dashboard —
/// usadas por el drag/resize de la Fase 5 para clamping.
class WidgetSizeConstraints {
  const WidgetSizeConstraints({
    this.minWidth = 1,
    this.minHeight = 1,
    this.maxWidth,
    this.maxHeight,
  });

  final double minWidth;
  final double minHeight;
  final double? maxWidth;
  final double? maxHeight;
}
