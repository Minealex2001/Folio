import '../../app/app_settings.dart';
import '../../config/models/dashboard_config.dart';
import '../../config/models/layout_config.dart';
import '../../config/models/theme_config.dart';
import '../../config/models/widget_instance_config.dart';
import '../../theme_engine/theme_config_defaults.dart';
import '../visual_pack.dart';
import '../visual_pack_manifest.dart';

/// Material 3 — el baseline literal de Folio (`kFolioDefaultTheme` +
/// `LayoutConfig.defaultConfig()`), para poder "resetear" explícitamente
/// desde el selector de packs en vez de tener que recordar los valores por
/// defecto.
VisualPack buildMaterial3Pack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'material3',
      name: 'Material 3',
      description: 'El aspecto por defecto de Folio — úsalo para resetear.',
      author: 'Folio',
    ),
    theme: ThemeConfig(
      id: 'pack_material3_theme',
      name: 'Material 3',
      light: kFolioDefaultTheme.light,
      dark: kFolioDefaultTheme.dark,
      typography: kFolioDefaultTheme.typography,
      shape: kFolioDefaultTheme.shape,
      elevation: kFolioDefaultTheme.elevation,
      spacing: kFolioDefaultTheme.spacing,
      motion: kFolioDefaultTheme.motion,
      icons: kFolioDefaultTheme.icons,
    ),
    layout: LayoutConfig.defaultConfig(id: 'pack_material3_layout'),
    dashboard: DashboardConfig(
      id: 'pack_material3_dashboard',
      name: 'Material 3',
      columns: 2,
      widgets: [
        for (var i = 0; i < WorkspaceHomeSectionIds.defaultLeft.length; i++)
          WidgetInstanceConfig(
            instanceId: 'material3_left_$i',
            pluginId: WorkspaceHomeSectionIds.defaultLeft[i],
            regionId: DashboardRegionIds.left,
            order: i,
          ),
        for (var i = 0; i < WorkspaceHomeSectionIds.defaultRight.length; i++)
          WidgetInstanceConfig(
            instanceId: 'material3_right_$i',
            pluginId: WorkspaceHomeSectionIds.defaultRight[i],
            regionId: DashboardRegionIds.right,
            order: i,
          ),
      ],
    ),
  );
}
