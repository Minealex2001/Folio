import 'package:flutter/widgets.dart';

import '../config/models/widget_instance_config.dart';
import 'widget_capabilities.dart';
import 'widget_plugin_context.dart';

/// Un tipo de widget instalable en el catálogo del dashboard (Fase 4/5).
/// Registrar uno nuevo en [WidgetCatalogRegistry] nunca requiere tocar el
/// motor de layout ni el shell — es el mecanismo concreto detrás de "añadir
/// un widget sin tocar el core" del brief.
abstract class FolioWidgetPlugin {
  const FolioWidgetPlugin();

  /// Id estable de catálogo (ej. 'calendar', 'tasks') — coincide con
  /// [WidgetInstanceConfig.pluginId].
  String get id;

  /// Nombre a mostrar, resuelto contra `BuildContext` para poder localizar.
  String displayName(BuildContext context);

  IconData get icon;

  /// Contenido real del widget para una instancia colocada.
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  );

  /// Panel de configuración propio del widget (ej. Calendario: "semana
  /// empieza lunes"); null si no tiene opciones configurables.
  Widget? buildSettings(
    BuildContext context,
    WidgetInstanceConfig instance,
    ValueChanged<Map<String, dynamic>> onSettingsChanged,
  ) => null;

  WidgetSizeConstraints get sizeConstraints => const WidgetSizeConstraints();

  /// Alto usado cuando la instancia no tiene `height` propio todavía (recién
  /// añadida, o migrada antes de que este plugin existiera). La mayoría de
  /// widgets built-in caben en 160px; unos pocos (ej. el reloj, que incluye
  /// saludo/fecha/titular) necesitan más — mejor que cada plugin lo declare
  /// a que el renderer adivine un valor fijo para todos.
  double get defaultHeight => 160;

  /// "Duplicable" del brief — si el usuario puede colocar más de una
  /// instancia de este plugin en el dashboard.
  bool get allowMultipleInstances => true;

  /// Qué puede hacer el usuario con una instancia colocada de este plugin
  /// (Fase 13) — movible/redimensionable/duplicable/cerrable. Afinable por
  /// instancia vía `WidgetInstanceConfig.capabilityOverrides`.
  WidgetCapabilities get capabilities => const WidgetCapabilities();

  /// Valores de tema por defecto de este plugin (Fase 23 — Widget Theme
  /// Tokens + Plugin Theme API), en la forma que el propio plugin elija.
  /// Folio nunca inspecciona estas claves — solo las transporta/persiste
  /// vía `ThemeConfig.widgetThemes` y las fusiona con la config del usuario
  /// en `ctx.widgetThemeFor(id, defaultTheme)`.
  Map<String, dynamic> get defaultTheme => const {};

  /// Editor de tema opcional (paralelo a [buildSettings], pero para
  /// `ThemeConfig.widgetThemes` en vez de `WidgetInstanceConfig.settings`);
  /// null si el plugin no expone tema configurable.
  Widget? buildThemeEditor(
    BuildContext context,
    Map<String, dynamic> theme,
    ValueChanged<Map<String, dynamic>> onThemeChanged,
  ) => null;
}
