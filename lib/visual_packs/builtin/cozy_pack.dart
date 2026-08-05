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

/// Cozy — acento cálido, radios grandes, sombras suaves, espaciado
/// generoso. Sidebar ancho, dashboard a dos columnas.
VisualPack buildCozyPack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'cozy',
      name: 'Cozy',
      description: 'Cálido y espacioso, con esquinas grandes y sombras suaves.',
      author: 'Folio',
    ),
    theme: ThemeConfig(
      id: 'pack_cozy_theme',
      name: 'Cozy',
      accentMode: 'custom', // ver minimal_pack.dart — obligatorio para seedArgb
      light: ThemeColorTokens(seedArgb: 0xFFD97757),
      dark: ThemeColorTokens(seedArgb: 0xFFE08A68, surfaceStyle: 'oled'),
      typography: ThemeTypographyTokens(baseSizeScale: 1.03),
      shape: ThemeShapeTokens(
        radiusXs: 8,
        radiusSm: 12,
        radiusMd: 18,
        radiusLg: 24,
        radiusXl: 32,
        radiusXxl: 40,
      ),
      elevation: ThemeElevationTokens(
        none: 0,
        appBarScrolled: 2,
        menu: 6,
        shadowOpacity: 0.14,
      ),
      spacing: ThemeSpacingTokens(xxs: 6, xs: 12, sm: 18, md: 24, lg: 32, xl: 48),
      motion: ThemeMotionTokens(),
      icons: ThemeIconTokens(),
    ),
    layout: LayoutConfig(
      id: 'pack_cozy_layout',
      name: 'Cozy',
      panels: {
        PanelRegionIds.sidebarLeft: PanelConfig(
          regionId: PanelRegionIds.sidebarLeft,
          visible: true,
          width: 340,
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
      id: 'pack_cozy_dashboard',
      name: 'Cozy',
      columns: 2,
      widgets: [
        WidgetInstanceConfig(
          instanceId: 'cozy_w1',
          pluginId: 'recents',
          regionId: DashboardRegionIds.left,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'cozy_w2',
          pluginId: 'mini_stats',
          regionId: DashboardRegionIds.left,
          order: 1,
        ),
        WidgetInstanceConfig(
          instanceId: 'cozy_w3',
          pluginId: 'agenda',
          regionId: DashboardRegionIds.right,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'cozy_w4',
          pluginId: 'root_pages',
          regionId: DashboardRegionIds.right,
          order: 1,
        ),
      ],
    ),
  );
}
