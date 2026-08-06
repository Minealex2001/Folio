import '../../config/models/dashboard_config.dart';
import '../../config/models/widget_instance_config.dart';

/// Plantilla "Developer" (Fase 30) — GitHub, tareas, base de datos y
/// atajos rápidos, con reloj a la izquierda.
DashboardConfig developerDashboardTemplate() {
  return DashboardConfig(
    id: 'template-developer',
    name: 'Developer',
    columns: 2,
    widgets: [
      WidgetInstanceConfig(
        instanceId: 'developer_clock',
        pluginId: 'clock',
        regionId: DashboardRegionIds.left,
        order: 0,
        height: 300,
      ),
      WidgetInstanceConfig(
        instanceId: 'developer_tasks',
        pluginId: 'tasks',
        regionId: DashboardRegionIds.left,
        order: 1,
      ),
      WidgetInstanceConfig(
        instanceId: 'developer_activity',
        pluginId: 'activity',
        regionId: DashboardRegionIds.left,
        order: 2,
      ),
      WidgetInstanceConfig(
        instanceId: 'developer_github',
        pluginId: 'github',
        regionId: DashboardRegionIds.right,
        order: 0,
      ),
      WidgetInstanceConfig(
        instanceId: 'developer_database',
        pluginId: 'database_view',
        regionId: DashboardRegionIds.right,
        order: 1,
      ),
      WidgetInstanceConfig(
        instanceId: 'developer_quick_actions',
        pluginId: 'quick_actions',
        regionId: DashboardRegionIds.right,
        order: 2,
      ),
    ],
  );
}
