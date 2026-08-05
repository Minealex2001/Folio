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

/// Minimal — elevación baja, radios pequeños, paleta neutra apagada, sin
/// sombras. Sidebar oculto por defecto, una sola columna, pocos widgets.
VisualPack buildMinimalPack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'minimal',
      name: 'Minimal',
      description: 'Superficies planas, radios pequeños, sin ruido visual.',
      author: 'Folio',
    ),
    theme: ThemeConfig(
      id: 'pack_minimal_theme',
      name: 'Minimal',
      // 'custom' es obligatorio para que light/dark.seedArgb de abajo se
      // usen de verdad — 'followSystem' (el default de ThemeConfig) los
      // ignora por completo y resuelve el color del acento del SO en su
      // lugar, que es el bug que hacía que el color del pack no cambiara.
      accentMode: 'custom',
      light: ThemeColorTokens(seedArgb: 0xFF6B7280),
      dark: ThemeColorTokens(seedArgb: 0xFF6B7280),
      typography: ThemeTypographyTokens(baseSizeScale: 0.97),
      shape: ThemeShapeTokens(
        radiusXs: 2,
        radiusSm: 4,
        radiusMd: 6,
        radiusLg: 8,
        radiusXl: 12,
        radiusXxl: 16,
      ),
      elevation: ThemeElevationTokens(
        none: 0,
        appBarScrolled: 0,
        menu: 1,
        shadowOpacity: 0.0,
      ),
      spacing: ThemeSpacingTokens(),
      motion: ThemeMotionTokens(),
      icons: ThemeIconTokens(),
    ),
    layout: LayoutConfig(
      id: 'pack_minimal_layout',
      name: 'Minimal',
      panels: {
        PanelRegionIds.sidebarLeft: PanelConfig(
          regionId: PanelRegionIds.sidebarLeft,
          visible: false,
          width: LayoutConfigDefaults.sidebarWidth,
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
      id: 'pack_minimal_dashboard',
      name: 'Minimal',
      columns: 1,
      widgets: [
        WidgetInstanceConfig(
          instanceId: 'minimal_w1',
          pluginId: 'daily_notes',
          regionId: DashboardRegionIds.left,
          order: 0,
        ),
        WidgetInstanceConfig(
          instanceId: 'minimal_w2',
          pluginId: 'tasks',
          regionId: DashboardRegionIds.left,
          order: 1,
        ),
      ],
    ),
  );
}
