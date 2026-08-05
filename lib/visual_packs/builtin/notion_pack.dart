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

/// Notion — claro, alto contraste, espaciado generoso, radios medios.
/// Sidebar único + main ancho, dos columnas.
VisualPack buildNotionPack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'notion',
      name: 'Notion',
      description: 'Claro, contrastado, orientado a documentos.',
      author: 'Folio',
    ),
    theme: ThemeConfig(
      id: 'pack_notion_theme',
      name: 'Notion',
      accentMode: 'custom', // ver minimal_pack.dart — obligatorio para seedArgb
      light: ThemeColorTokens(seedArgb: 0xFF2383E2),
      dark: ThemeColorTokens(seedArgb: 0xFF2383E2),
      typography: ThemeTypographyTokens(fontFamily: 'Inter'),
      shape: ThemeShapeTokens(
        radiusXs: 3,
        radiusSm: 6,
        radiusMd: 9,
        radiusLg: 12,
        radiusXl: 16,
        radiusXxl: 20,
      ),
      elevation: ThemeElevationTokens(
        none: 0,
        appBarScrolled: 1,
        menu: 3,
        shadowOpacity: 0.06,
      ),
      spacing: ThemeSpacingTokens(xxs: 6, xs: 10, sm: 16, md: 20, lg: 28, xl: 44),
      motion: ThemeMotionTokens(),
      icons: ThemeIconTokens(),
    ),
    layout: LayoutConfig(
      id: 'pack_notion_layout',
      name: 'Notion',
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
      id: 'pack_notion_dashboard',
      name: 'Notion',
      columns: 2,
      widgets: [
        WidgetInstanceConfig(
          instanceId: 'notion_w1',
          pluginId: 'root_pages',
          regionId: DashboardRegionIds.left,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'notion_w2',
          pluginId: 'recents',
          regionId: DashboardRegionIds.left,
          order: 1,
        ),
        WidgetInstanceConfig(
          instanceId: 'notion_w3',
          pluginId: 'database_view',
          regionId: DashboardRegionIds.right,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'notion_w4',
          pluginId: 'tasks',
          regionId: DashboardRegionIds.right,
          order: 1,
        ),
      ],
    ),
  );
}
