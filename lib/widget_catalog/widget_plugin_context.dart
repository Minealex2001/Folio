import 'package:flutter/foundation.dart';

import '../app/app_settings.dart';
import '../config/config_store.dart';
import '../config/models/widget_theme_tokens.dart';
import '../services/cloud_account/cloud_account_controller.dart';
import '../services/folio_cloud/folio_cloud_entitlements.dart';
import '../session/vault_session.dart';
import '../theme_engine/widget_theme_resolver.dart';

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
    this.cloudAccount,
    this.folioCloudEntitlements,
    this.onOpenSearch,
    this.onCreatePage,
    this.onSelectPage,
    this.onUpdateInstanceSettings,
    this.onOpenSettings,
    this.onOpenFolioCloudPitch,
    this.widgetThemeTokens,
  });

  /// Todavía necesario para cosas transversales no migradas a [ConfigStore]
  /// (tokens de auth, feature flags, etc.).
  final AppSettings appSettings;
  final ConfigStore configStore;

  /// Solo lectura en la práctica: los plugins built-in leen `pages`/tareas
  /// de aquí (recientes, raíz, tareas) — ninguno debería mutarla.
  final VaultSession session;

  /// Cuenta / entitlements de Folio Cloud (opcionales: null fuera del shell).
  final CloudAccountController? cloudAccount;
  final FolioCloudEntitlementsController? folioCloudEntitlements;

  final void Function([String? query])? onOpenSearch;
  final VoidCallback? onCreatePage;
  final ValueChanged<String>? onSelectPage;

  /// Persiste `WidgetInstanceConfig.settings` para [instanceId].
  final void Function(String instanceId, Map<String, dynamic> settings)?
      onUpdateInstanceSettings;

  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenFolioCloudPitch;

  /// `ThemeConfig.widgetThemes` del tema activo (Fase 23) — null en
  /// llamadores que aún no lo enhebran, en cuyo caso [widgetThemeFor]
  /// devuelve siempre el `defaultTheme` del plugin.
  final WidgetThemeTokens? widgetThemeTokens;

  /// Tema efectivo de [pluginId] — fusión de su `defaultTheme` con lo
  /// configurado en [widgetThemeTokens].
  Map<String, dynamic> widgetThemeFor(
    String pluginId,
    Map<String, dynamic> pluginDefault,
  ) => themeFor(widgetThemeTokens, pluginId, pluginDefault);
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
