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

/// Glass — opacidad/blur altos, sombras suaves grandes, acentos vívidos.
/// Preferencia por paneles flotantes sobre anclados.
VisualPack buildGlassPack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'glass',
      name: 'Glass',
      description: 'Translúcido y flotante, con acentos vívidos.',
      author: 'Folio',
    ),
    theme: ThemeConfig(
      id: 'pack_glass_theme',
      name: 'Glass',
      accentMode: 'custom', // ver minimal_pack.dart — obligatorio para seedArgb
      light: ThemeColorTokens(seedArgb: 0xFF00C2CB),
      dark: ThemeColorTokens(seedArgb: 0xFF00C2CB),
      typography: ThemeTypographyTokens(),
      shape: ThemeShapeTokens(
        radiusXs: 8,
        radiusSm: 14,
        radiusMd: 20,
        radiusLg: 26,
        radiusXl: 32,
        radiusXxl: 40,
      ),
      elevation: ThemeElevationTokens(
        none: 0,
        appBarScrolled: 2,
        menu: 10,
        shadowOpacity: 0.2,
      ),
      spacing: ThemeSpacingTokens(),
      motion: ThemeMotionTokens(),
      icons: ThemeIconTokens(),
      surfaceOpacity: 0.65,
    ),
    layout: LayoutConfig(
      id: 'pack_glass_layout',
      name: 'Glass',
      panels: {
        PanelRegionIds.sidebarLeft: PanelConfig(
          regionId: PanelRegionIds.sidebarLeft,
          visible: false,
        ),
        PanelRegionIds.main: PanelConfig(
          regionId: PanelRegionIds.main,
          visible: true,
        ),
        PanelRegionIds.floatingAi: PanelConfig(
          regionId: PanelRegionIds.floatingAi,
          visible: true,
          width: 380,
          height: 500,
        ),
        PanelRegionIds.floatingCollab: PanelConfig(
          regionId: PanelRegionIds.floatingCollab,
          visible: true,
        ),
      },
    ),
    dashboard: DashboardConfig(
      id: 'pack_glass_dashboard',
      name: 'Glass',
      columns: 2,
      widgets: [
        WidgetInstanceConfig(
          instanceId: 'glass_w1',
          pluginId: 'folio_cloud',
          regionId: DashboardRegionIds.left,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'glass_w2',
          pluginId: 'clock',
          regionId: DashboardRegionIds.right,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'glass_w3',
          pluginId: 'weather',
          regionId: DashboardRegionIds.right,
          order: 1,
        ),
      ],
    ),
  );
}
