import '../../config/models/component_style_tokens.dart';
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
import '../../config/models/token_ref.dart';
import '../../config/models/visual_style.dart';
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
      typography: ThemeTypographyTokens(fontFamily: 'Oswald'),
      shape: ThemeShapeTokens(
        radiusXs: 0,
        radiusSm: 0,
        radiusMd: 20,
        radiusLg: 24,
        radiusXl: 0,
        radiusXxl: 0,
        componentRadiusOverrides: const {
          'filledButton': 20,
          'outlinedButton': 20,
          'textButton': 12,
          'chip': 0,
          'card': 0,
        },
      ),
      elevation: ThemeElevationTokens(
        none: 0,
        appBarScrolled: 3,
        menu: 6,
        shadowOpacity: 0.25,
      ),
      spacing: ThemeSpacingTokens(),
      motion: ThemeMotionTokens(
        shortMs: 80,
        short2Ms: 120,
        mediumMs: 160,
        themeChangeMs: 180,
        curveName: 'linear',
      ),
      icons: ThemeIconTokens(),
      visualStyle: const VisualStyle(
        densityMode: 'compact',
        borderEnabled: true,
        borderWidth: TokenRef.literal(2),
        borderOpacity: TokenRef.literal(0.7),
        windowCorners: 'square',
      ),
      componentStyles: const ComponentStyleTokens(
        components: {
          'filledButton': ComponentStyleEntry(
            radius: TokenRef.literal(20),
            border: true,
          ),
          'outlinedButton': ComponentStyleEntry(
            radius: TokenRef.literal(20),
            border: true,
          ),
          'card': ComponentStyleEntry(radius: TokenRef.literal(0), border: true),
        },
      ),
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
      columns: 2,
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
          pluginId: 'quick_actions',
          regionId: DashboardRegionIds.right,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'retro_w4',
          pluginId: 'tip',
          regionId: DashboardRegionIds.right,
          order: 1,
        ),
      ],
    ),
  );
}
