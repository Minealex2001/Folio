import 'package:flutter/foundation.dart';

import '../app/app_settings.dart';
import '../config/config_store.dart';
import '../session/vault_session.dart';

/// Superficie de capacidad que un [FolioWidgetPlugin] recibe al construirse
/// — deliberadamente angosta (no la app/router completos): un plugin puede
/// leer settings/config/sesión y disparar un puñado de acciones concretas
/// (buscar, crear página, seleccionar página), pero no navegar libremente
/// ni tocar el core del shell. Ver Fase 4 del plan de personalización —
/// "añadir un widget nunca toca el core" solo se sostiene si los plugins no
/// tienen acceso libre.
class WidgetPluginContext {
  const WidgetPluginContext({
    required this.appSettings,
    required this.configStore,
    required this.session,
    this.onOpenSearch,
    this.onCreatePage,
    this.onSelectPage,
  });

  /// Todavía necesario para cosas transversales no migradas a [ConfigStore]
  /// (tokens de auth, feature flags, etc.).
  final AppSettings appSettings;
  final ConfigStore configStore;

  /// Solo lectura en la práctica: los plugins built-in leen `pages`/tareas
  /// de aquí (recientes, raíz, tareas) — ninguno debería mutarla.
  final VaultSession session;

  final void Function([String? query])? onOpenSearch;
  final VoidCallback? onCreatePage;
  final ValueChanged<String>? onSelectPage;
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
