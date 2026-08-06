import '../../config/models/dashboard_config.dart';
import '../../config/models/widget_instance_config.dart';
import '../../layout_engine/responsive/breakpoints.dart';

/// Resuelve el [DashboardConfig] efectivo para un ancho de viewport dado
/// (Fase 26) — equivalente de `ResponsiveLayoutResolver` (Fase 7) pero para
/// widgets de dashboard en vez de paneles: fusiona
/// `base.responsiveOverrides[breakpoint]` (parcial — solo los widgets, por
/// `instanceId`, que difieren) sobre `base.widgets`, preservando el orden
/// de la lista base.
abstract final class DashboardResponsiveResolver {
  static DashboardConfig resolveForWidth(DashboardConfig base, double width) {
    final breakpoint = Breakpoints.resolve(width);
    final override = base.responsiveOverrides?[breakpoint.name];
    if (override == null || override.widgets.isEmpty) return base;

    final overridesById = <String, WidgetInstanceConfig>{
      for (final w in override.widgets) w.instanceId: w,
    };
    final mergedWidgets = [
      for (final w in base.widgets) overridesById[w.instanceId] ?? w,
    ];
    return base.copyWith(widgets: mergedWidgets);
  }
}
