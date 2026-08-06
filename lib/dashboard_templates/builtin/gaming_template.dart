import '../../config/models/dashboard_config.dart';
import '../../config/models/widget_instance_config.dart';

/// Plantilla "Gaming" (Fase 30) — reloj/actividad y música como eje
/// central, sin componentes de productividad pesados (sin tareas/hábitos).
DashboardConfig gamingDashboardTemplate() {
  return DashboardConfig(
    id: 'template-gaming',
    name: 'Gaming',
    columns: 2,
    widgets: [
      WidgetInstanceConfig(
        instanceId: 'gaming_clock',
        pluginId: 'clock',
        regionId: DashboardRegionIds.left,
        order: 0,
        height: 300,
      ),
      WidgetInstanceConfig(
        instanceId: 'gaming_activity',
        pluginId: 'activity',
        regionId: DashboardRegionIds.left,
        order: 1,
      ),
      WidgetInstanceConfig(
        instanceId: 'gaming_music',
        pluginId: 'music',
        regionId: DashboardRegionIds.right,
        order: 0,
      ),
      WidgetInstanceConfig(
        instanceId: 'gaming_mini_stats',
        pluginId: 'mini_stats',
        regionId: DashboardRegionIds.right,
        order: 1,
      ),
      WidgetInstanceConfig(
        instanceId: 'gaming_quick_actions',
        pluginId: 'quick_actions',
        regionId: DashboardRegionIds.right,
        order: 2,
      ),
    ],
  );
}
