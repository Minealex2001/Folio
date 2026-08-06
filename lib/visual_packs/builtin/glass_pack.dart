import '../../config/models/dashboard_config.dart';
import '../../config/models/layout_config.dart';
import '../../config/models/panel_config.dart';
import '../../config/models/panel_region_ids.dart';
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

/// Glass — opacidad/blur altos, sombras suaves grandes, acentos vívidos.
/// Preferencia por paneles flotantes sobre anclados. Primer consumidor
/// real de `VisualStyle`/`ThemeLayerTokens` (Fase 20/18) — no solo
/// `surfaceOpacity` plano: diálogos/menús aún más transparentes que el
/// resto, con blur real en la capa overlay, y backdrop de ventana con
/// blur (no tiene sentido en móvil, de ahí `platformSupport`).
VisualPack buildGlassPack() {
  return VisualPack(
    manifest: const VisualPackManifest(
      id: 'glass',
      name: 'Glass',
      description: 'Translúcido y flotante, con acentos vívidos.',
      author: 'Folio',
      platformSupport: PlatformSupport(supportsMobile: false),
    ),
    theme: ThemeConfig(
      id: 'pack_glass_theme',
      name: 'Glass',
      accentMode: 'custom', // ver minimal_pack.dart — obligatorio para seedArgb
      light: ThemeColorTokens(seedArgb: 0xFF00C2CB),
      dark: ThemeColorTokens(seedArgb: 0xFF00C2CB),
      typography: ThemeTypographyTokens(fontFamily: 'Lexend'),
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
      motion: ThemeMotionTokens(
        shortMs: 100,
        short2Ms: 160,
        mediumMs: 220,
        themeChangeMs: 260,
        curveName: 'easeOutCubic',
      ),
      icons: ThemeIconTokens(),
      surfaceOpacity: 0.65,
      visualStyle: const VisualStyle(
        glassDialogOpacity: TokenRef.literal(0.5),
        glassMenuOpacity: TokenRef.literal(0.55),
        glassSidebarOpacity: TokenRef.literal(0.7),
        glassPanelOpacity: TokenRef.literal(0.6),
        windowBackdrop: 'blur',
      ),
      layers: const ThemeLayerTokens(
        panel: LayerStyle(
          opacity: TokenRef.literal(0.75),
          blurSigma: 14,
        ),
        overlay: LayerStyle(
          shadow: true,
          opacity: TokenRef.literal(0.85),
          blurSigma: 16,
        ),
      ),
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
          settings: const {'weatherCity': 'Madrid', 'weatherCelsius': true},
        ),
        WidgetInstanceConfig(
          instanceId: 'glass_w4',
          pluginId: 'music',
          regionId: DashboardRegionIds.left,
          order: 1,
        ),
      ],
    ),
  );
}
