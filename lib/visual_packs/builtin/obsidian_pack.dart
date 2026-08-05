import '../../config/models/dashboard_config.dart';
import '../../config/models/layout_config.dart';
import '../../config/models/panel_config.dart';
import '../../config/models/panel_region_ids.dart';
import '../../config/models/theme_color_tokens.dart';
import '../../config/models/theme_config.dart';
import '../../config/models/theme_elevation_tokens.dart';
import '../../config/models/theme_icon_tokens.dart';
import '../../config/models/theme_motion_tokens.dart';
import '../../config/models/theme_shape_tokens.dart';
import '../../config/models/theme_spacing_tokens.dart';
import '../../config/models/theme_typography_tokens.dart';
import '../../config/models/widget_instance_config.dart';
import '../visual_pack.dart';
import '../visual_pack_manifest.dart';

/// Obsidian — paleta oscura-primero, radios angulosos, tipografía
/// monospace-adyacente. Sidebar ancho y bloqueado, tres columnas de
/// dashboard, énfasis en actividad/tareas/database.
VisualPack buildObsidianPack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'obsidian',
      name: 'Obsidian',
      description: 'Oscuro, anguloso, denso en información.',
      author: 'Folio',
    ),
    theme: ThemeConfig(
      id: 'pack_obsidian_theme',
      name: 'Obsidian',
      light: ThemeColorTokens(seedArgb: 0xFF7C5CFF),
      dark: ThemeColorTokens(seedArgb: 0xFF7C5CFF, surfaceStyle: 'oled'),
      typography: ThemeTypographyTokens(fontFamily: 'JetBrains Mono'),
      shape: ThemeShapeTokens(
        radiusXs: 0,
        radiusSm: 2,
        radiusMd: 4,
        radiusLg: 6,
        radiusXl: 8,
        radiusXxl: 10,
      ),
      elevation: ThemeElevationTokens(
        none: 0,
        appBarScrolled: 0,
        menu: 2,
        shadowOpacity: 0.05,
      ),
      spacing: ThemeSpacingTokens(),
      motion: ThemeMotionTokens(),
      icons: ThemeIconTokens(),
    ),
    layout: LayoutConfig(
      id: 'pack_obsidian_layout',
      name: 'Obsidian',
      panels: {
        PanelRegionIds.sidebarLeft: PanelConfig(
          regionId: PanelRegionIds.sidebarLeft,
          visible: true,
          width: 300,
          locked: true,
        ),
        PanelRegionIds.main: PanelConfig(
          regionId: PanelRegionIds.main,
          visible: true,
        ),
        PanelRegionIds.floatingAi: PanelConfig(
          regionId: PanelRegionIds.floatingAi,
          visible: false,
        ),
        PanelRegionIds.floatingCollab: PanelConfig(
          regionId: PanelRegionIds.floatingCollab,
          visible: false,
        ),
      },
    ),
    dashboard: DashboardConfig(
      id: 'pack_obsidian_dashboard',
      name: 'Obsidian',
      columns: 3,
      widgets: [
        WidgetInstanceConfig(
          instanceId: 'obsidian_w1',
          pluginId: 'activity',
          regionId: DashboardRegionIds.left,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'obsidian_w2',
          pluginId: 'tasks',
          regionId: DashboardRegionIds.left,
          order: 1,
        ),
        WidgetInstanceConfig(
          instanceId: 'obsidian_w3',
          pluginId: 'recents',
          regionId: DashboardRegionIds.right,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'obsidian_w4',
          pluginId: 'database_view',
          regionId: DashboardRegionIds.right,
          order: 1,
        ),
      ],
    ),
  );
}
