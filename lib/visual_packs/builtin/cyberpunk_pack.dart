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

/// Cyberpunk — acento neón sobre casi-negro, sombras tipo glow, curvas
/// rápidas/agudas. Sidebar angosto, dashboard multi-columna, panel de IA
/// flotante destacado.
VisualPack buildCyberpunkPack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'cyberpunk',
      name: 'Cyberpunk',
      description: 'Neón sobre negro, rápido y anguloso.',
      author: 'Folio',
    ),
    theme: ThemeConfig(
      id: 'pack_cyberpunk_theme',
      name: 'Cyberpunk',
      accentMode: 'custom', // ver minimal_pack.dart — obligatorio para seedArgb
      light: ThemeColorTokens(seedArgb: 0xFFFF2E9A),
      dark: ThemeColorTokens(seedArgb: 0xFFFF2E9A, surfaceStyle: 'oled'),
      typography: ThemeTypographyTokens(),
      shape: ThemeShapeTokens(
        radiusXs: 0,
        radiusSm: 1,
        radiusMd: 2,
        radiusLg: 3,
        radiusXl: 4,
        radiusXxl: 6,
      ),
      elevation: ThemeElevationTokens(
        none: 0,
        appBarScrolled: 2,
        menu: 12,
        shadowOpacity: 0.35,
      ),
      spacing: ThemeSpacingTokens(),
      motion: ThemeMotionTokens(
        shortMs: 80,
        short2Ms: 130,
        mediumMs: 180,
        themeChangeMs: 200,
        curveName: 'easeOutExpo',
      ),
      icons: ThemeIconTokens(),
    ),
    layout: LayoutConfig(
      id: 'pack_cyberpunk_layout',
      name: 'Cyberpunk',
      panels: {
        PanelRegionIds.sidebarLeft: PanelConfig(
          regionId: PanelRegionIds.sidebarLeft,
          visible: true,
          width: 220,
        ),
        PanelRegionIds.main: PanelConfig(
          regionId: PanelRegionIds.main,
          visible: true,
        ),
        PanelRegionIds.floatingAi: PanelConfig(
          regionId: PanelRegionIds.floatingAi,
          visible: true,
          width: 360,
          height: 480,
        ),
        PanelRegionIds.floatingCollab: PanelConfig(
          regionId: PanelRegionIds.floatingCollab,
          visible: false,
        ),
      },
    ),
    dashboard: DashboardConfig(
      id: 'pack_cyberpunk_dashboard',
      name: 'Cyberpunk',
      columns: 3,
      widgets: [
        WidgetInstanceConfig(
          instanceId: 'cyberpunk_w1',
          pluginId: 'ai',
          regionId: DashboardRegionIds.left,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'cyberpunk_w2',
          pluginId: 'github',
          regionId: DashboardRegionIds.left,
          order: 1,
        ),
        WidgetInstanceConfig(
          instanceId: 'cyberpunk_w3',
          pluginId: 'activity',
          regionId: DashboardRegionIds.right,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'cyberpunk_w4',
          pluginId: 'mini_stats',
          regionId: DashboardRegionIds.right,
          order: 1,
        ),
      ],
    ),
  );
}
