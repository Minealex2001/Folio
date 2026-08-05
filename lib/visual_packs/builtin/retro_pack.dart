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

/// Retro — paleta saturada/contrastada, radios chunky en unos componentes y
/// cuadrados en otros (`componentRadiusOverrides`), curvas de movimiento
/// sin easing. Dashboard denso, sin chrome flotante.
VisualPack buildRetroPack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'retro',
      name: 'Retro',
      description: 'Saturado y contrastado, con esquinas mixtas.',
      author: 'Folio',
    ),
    theme: ThemeConfig(
      id: 'pack_retro_theme',
      name: 'Retro',
      accentMode: 'custom', // ver minimal_pack.dart — obligatorio para seedArgb
      light: ThemeColorTokens(seedArgb: 0xFFE8A33D),
      dark: ThemeColorTokens(seedArgb: 0xFFE8A33D),
      typography: ThemeTypographyTokens(),
      shape: ThemeShapeTokens(
        radiusXs: 0,
        radiusSm: 0,
        radiusMd: 20,
        radiusLg: 24,
        radiusXl: 0,
        radiusXxl: 0,
        componentRadiusOverrides: const {'button': 20, 'chip': 0, 'card': 0},
      ),
      elevation: ThemeElevationTokens(
        none: 0,
        appBarScrolled: 3,
        menu: 6,
        shadowOpacity: 0.25,
      ),
      spacing: ThemeSpacingTokens(),
      motion: ThemeMotionTokens(curveName: 'linear'),
      icons: ThemeIconTokens(),
    ),
    layout: LayoutConfig(
      id: 'pack_retro_layout',
      name: 'Retro',
      panels: {
        PanelRegionIds.sidebarLeft: PanelConfig(
          regionId: PanelRegionIds.sidebarLeft,
          visible: true,
          width: 260,
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
      id: 'pack_retro_dashboard',
      name: 'Retro',
      columns: 4,
      widgets: [
        WidgetInstanceConfig(
          instanceId: 'retro_w1',
          pluginId: 'activity',
          regionId: DashboardRegionIds.left,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'retro_w2',
          pluginId: 'mini_stats',
          regionId: DashboardRegionIds.left,
          order: 1,
        ),
        WidgetInstanceConfig(
          instanceId: 'retro_w3',
          pluginId: 'rss',
          regionId: DashboardRegionIds.right,
          order: 0,
        ),
      ],
    ),
  );
}
