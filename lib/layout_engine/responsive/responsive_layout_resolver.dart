import '../../config/models/layout_config.dart';
import '../../config/models/panel_config.dart';
import 'breakpoints.dart';

/// Resuelve el [LayoutConfig] efectivo para un ancho de viewport dado,
/// fusionando `base.responsiveOverrides[breakpoint]` (parcial — solo los
/// paneles que difieren) sobre `base.panels`. Mantiene el JSON de presets
/// pequeño: un pack no necesita cuatro copias completas del layout, solo
/// los paneles que cambian por breakpoint (ej. "en mobile, ocultar
/// sidebarLeft").
abstract final class ResponsiveLayoutResolver {
  static LayoutConfig resolveForWidth(LayoutConfig base, double width) {
    final breakpoint = Breakpoints.resolve(width);
    final override = base.responsiveOverrides?[breakpoint.name];
    if (override == null || override.panels.isEmpty) return base;

    final mergedPanels = <String, PanelConfig>{...base.panels};
    for (final entry in override.panels.entries) {
      mergedPanels[entry.key] = entry.value;
    }
    return base.copyWith(panels: mergedPanels);
  }
}
