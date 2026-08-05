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

/// macOS — superficies translúcidas (`surfaceOpacity` < 1), tipografía
/// redondeada. Sidebar izquierdo + panel de IA flotante visible.
VisualPack buildMacosPack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'macos',
      name: 'macOS',
      description: 'Superficies translúcidas y tipografía redondeada.',
      author: 'Folio',
    ),
    theme: ThemeConfig(
      id: 'pack_macos_theme',
      name: 'macOS',
      accentMode: 'custom', // ver minimal_pack.dart — obligatorio para seedArgb
      light: ThemeColorTokens(seedArgb: 0xFF0A84FF),
      dark: ThemeColorTokens(seedArgb: 0xFF0A84FF),
      typography: ThemeTypographyTokens(fontFamily: 'Nunito'),
      shape: ThemeShapeTokens(
        radiusXs: 4,
        radiusSm: 8,
        radiusMd: 12,
        radiusLg: 16,
        radiusXl: 20,
        radiusXxl: 26,
        componentRadiusOverrides: const {
          'filledButton': 22,
          'outlinedButton': 22,
          'chip': 999,
        },
      ),
      elevation: ThemeElevationTokens(
        none: 0,
        appBarScrolled: 1,
        menu: 8,
        shadowOpacity: 0.16,
      ),
      spacing: ThemeSpacingTokens(),
      motion: ThemeMotionTokens(),
      icons: ThemeIconTokens(),
      surfaceOpacity: 0.85,
    ),
    layout: LayoutConfig(
      id: 'pack_macos_layout',
      name: 'macOS',
      panels: {
        PanelRegionIds.sidebarLeft: PanelConfig(
          regionId: PanelRegionIds.sidebarLeft,
          visible: true,
          width: 280,
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
      id: 'pack_macos_dashboard',
      name: 'macOS',
      columns: 2,
      widgets: [
        WidgetInstanceConfig(
          instanceId: 'macos_w1',
          pluginId: 'calendar',
          regionId: DashboardRegionIds.left,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'macos_w2',
          pluginId: 'tasks',
          regionId: DashboardRegionIds.left,
          order: 1,
        ),
        WidgetInstanceConfig(
          instanceId: 'macos_w3',
          pluginId: 'recents',
          regionId: DashboardRegionIds.right,
          order: 0,
        ),
      ],
    ),
  );
}
