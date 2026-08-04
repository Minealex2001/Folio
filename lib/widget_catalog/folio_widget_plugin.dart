import 'package:flutter/widgets.dart';

import '../config/models/widget_instance_config.dart';
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

  /// "Duplicable" del brief — si el usuario puede colocar más de una
  /// instancia de este plugin en el dashboard.
  bool get allowMultipleInstances => true;
}
