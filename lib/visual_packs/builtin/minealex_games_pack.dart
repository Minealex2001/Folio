import '../../app/folio_brand_palette.dart';
import '../../config/models/component_style_tokens.dart';
import '../../config/models/dashboard_config.dart';
import '../../config/models/layout_config.dart';
import '../../config/models/panel_config.dart';
import '../../config/models/panel_region_ids.dart';
import '../../config/models/semantic_color_tokens.dart';
import '../../config/models/theme_color_tokens.dart';
import '../../config/models/theme_config.dart';
import '../../config/models/theme_elevation_tokens.dart';
import '../../config/models/theme_icon_tokens.dart';
import '../../config/models/theme_layer_tokens.dart';
import '../../config/models/theme_motion_tokens.dart';
import '../../config/models/theme_shape_tokens.dart';
import '../../config/models/theme_spacing_tokens.dart';
import '../../config/models/theme_typography_tokens.dart';
import '../../config/models/token_ref.dart';
import '../../config/models/visual_style.dart';
import '../../config/models/widget_instance_config.dart';
import '../visual_pack.dart';
import '../visual_pack_manifest.dart';

/// Minealex Games — estética de marca: neón cyan/magenta sobre negro OLED,
/// botones tipo pill, motion snappy. Alineado con [FolioBrandPalette].
VisualPack buildMinealexGamesPack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'minealex_games',
      name: 'Minealex Games',
      description:
          'Marca Minealex — neón cyan y magenta sobre negro profundo.',
      author: 'Minealex Games',
    ),
    theme: ThemeConfig(
      id: 'pack_minealex_games_theme',
      name: 'Minealex Games',
      // folioDefault → FolioBrandPalette (cyan #00F3FF + magenta #FF00FF
      // explícitos). `custom`+fromSeed no reproduce esa pareja de marca.
      accentMode: 'folioDefault',
      light: ThemeColorTokens(seedArgb: kFolioBrandPrimaryArgb),
      dark: ThemeColorTokens(
        seedArgb: kFolioBrandPrimaryArgb,
        surfaceStyle: 'oled',
      ),
      typography: ThemeTypographyTokens(
        fontFamily: 'Space Grotesk',
        baseSizeScale: 1.0,
      ),
      shape: ThemeShapeTokens(
        radiusXs: 6,
        radiusSm: 10,
        radiusMd: 16,
        radiusLg: 20,
        radiusXl: 24,
        radiusXxl: 32,
        componentRadiusOverrides: const {
          'filledButton': 999,
          'outlinedButton': 999,
          'textButton': 999,
          'chip': 999,
          'segmentedButton': 16,
        },
      ),
      elevation: ThemeElevationTokens(
        none: 0,
        appBarScrolled: 2,
        menu: 8,
        shadowOpacity: 0.28,
      ),
      spacing: ThemeSpacingTokens(),
      motion: ThemeMotionTokens(
        shortMs: 100,
        short2Ms: 160,
        mediumMs: 220,
        themeChangeMs: 280,
        curveName: 'easeOutExpo',
      ),
      icons: ThemeIconTokens(),
      surfaceOpacity: 0.92,
      visualStyle: const VisualStyle(
        densityMode: 'compact',
        iconSize: TokenRef.literal(20),
      ),
      layers: const ThemeLayerTokens(
        overlay: LayerStyle(
          shadow: true,
          opacity: TokenRef.literal(0.9),
          blurSigma: 8,
        ),
      ),
      semanticColors: const SemanticColorTokens(
        selection: TokenRef.literal(0xFF00F3FF),
        focus: TokenRef.literal(0xFF00F3FF),
        sidebarHover: TokenRef.literal(0x33FF00FF),
      ),
      componentStyles: const ComponentStyleTokens(
        components: {
          'filledButton': ComponentStyleEntry(radius: TokenRef.literal(999)),
          'outlinedButton': ComponentStyleEntry(radius: TokenRef.literal(999)),
          'chip': ComponentStyleEntry(radius: TokenRef.literal(999)),
        },
      ),
    ),
    layout: LayoutConfig(
      id: 'pack_minealex_games_layout',
      name: 'Minealex Games',
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
      id: 'pack_minealex_games_dashboard',
      name: 'Minealex Games',
      columns: 2,
      widgets: [
        WidgetInstanceConfig(
          instanceId: 'minealex_w1',
          pluginId: 'clock',
          regionId: DashboardRegionIds.left,
          order: 0,
          height: 280,
        ),
        WidgetInstanceConfig(
          instanceId: 'minealex_w2',
          pluginId: 'folio_cloud',
          regionId: DashboardRegionIds.left,
          order: 1,
        ),
        WidgetInstanceConfig(
          instanceId: 'minealex_w3',
          pluginId: 'tasks',
          regionId: DashboardRegionIds.right,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'minealex_w4',
          pluginId: 'recents',
          regionId: DashboardRegionIds.right,
          order: 1,
        ),
        WidgetInstanceConfig(
          instanceId: 'minealex_w5',
          pluginId: 'mini_stats',
          regionId: DashboardRegionIds.right,
          order: 2,
        ),
      ],
    ),
  );
}
