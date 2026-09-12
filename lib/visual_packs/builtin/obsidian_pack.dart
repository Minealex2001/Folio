import '../../config/models/dashboard_config.dart';
import '../../config/models/layout_config.dart';
import '../../config/models/panel_config.dart';
import '../../config/models/panel_region_ids.dart';
import '../../config/models/semantic_color_tokens.dart';
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

/// Obsidian — paleta oscura-primero, radios angulosos, tipografía
/// monospace. Sidebar ancho y bloqueado, dashboard a dos columnas,
/// énfasis en actividad/tareas/database.
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
      accentMode: 'custom', // ver minimal_pack.dart — obligatorio para seedArgb
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
      spacing: ThemeSpacingTokens(xxs: 2, xs: 6, sm: 10, md: 14, lg: 20, xl: 32),
      motion: ThemeMotionTokens(),
      icons: ThemeIconTokens(),
      visualStyle: const VisualStyle(
        densityMode: 'compact',
        borderEnabled: true,
        borderWidth: TokenRef.literal(1),
        borderOpacity: TokenRef.literal(0.45),
      ),
      semanticColors: const SemanticColorTokens(
        sidebarBackground: TokenRef.literal(0xFF050505),
      ),
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
      columns: 2,
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
