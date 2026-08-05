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

/// Paper — superficies off-white, tipografía serif-leaning, elevación
/// plana. Sidebar clásico + main, sin paneles flotantes.
VisualPack buildPaperPack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'paper',
      name: 'Paper',
      description: 'Superficies cálidas tipo papel, sin sombras ni flotantes.',
      author: 'Folio',
    ),
    theme: ThemeConfig(
      id: 'pack_paper_theme',
      name: 'Paper',
      accentMode: 'custom', // ver minimal_pack.dart — obligatorio para seedArgb
      light: ThemeColorTokens(seedArgb: 0xFF8A6D4B),
      dark: ThemeColorTokens(seedArgb: 0xFF8A6D4B),
      typography: ThemeTypographyTokens(fontFamily: 'Georgia'),
      shape: ThemeShapeTokens(
        radiusXs: 2,
        radiusSm: 4,
        radiusMd: 6,
        radiusLg: 8,
        radiusXl: 10,
        radiusXxl: 12,
      ),
      elevation: ThemeElevationTokens(
        none: 0,
        appBarScrolled: 0,
        menu: 0,
        shadowOpacity: 0.0,
      ),
      spacing: ThemeSpacingTokens(),
      motion: ThemeMotionTokens(),
      icons: ThemeIconTokens(),
    ),
    layout: LayoutConfig(
      id: 'pack_paper_layout',
      name: 'Paper',
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
      id: 'pack_paper_dashboard',
      name: 'Paper',
      columns: 1,
      widgets: [
        WidgetInstanceConfig(
          instanceId: 'paper_w1',
          pluginId: 'daily_notes',
          regionId: DashboardRegionIds.left,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'paper_w2',
          pluginId: 'recents',
          regionId: DashboardRegionIds.left,
          order: 1,
        ),
        WidgetInstanceConfig(
          instanceId: 'paper_w3',
          pluginId: 'bookmarks',
          regionId: DashboardRegionIds.left,
          order: 2,
        ),
      ],
    ),
  );
}
