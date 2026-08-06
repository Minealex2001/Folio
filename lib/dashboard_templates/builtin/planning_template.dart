import '../../config/models/dashboard_config.dart';
import '../../config/models/widget_instance_config.dart';

/// Plantilla "Planning" (Fase 30) — calendario + agenda como eje central,
/// tareas y hábitos de apoyo, atajos rápidos para crear.
DashboardConfig planningDashboardTemplate() {
  return DashboardConfig(
    id: 'template-planning',
    name: 'Planning',
    columns: 2,
    widgets: [
      WidgetInstanceConfig(
        instanceId: 'planning_calendar',
        pluginId: 'calendar',
        regionId: DashboardRegionIds.left,
        order: 0,
      ),
      WidgetInstanceConfig(
        instanceId: 'planning_agenda',
        pluginId: 'agenda',
        regionId: DashboardRegionIds.left,
        order: 1,
      ),
      WidgetInstanceConfig(
        instanceId: 'planning_tasks',
        pluginId: 'tasks',
        regionId: DashboardRegionIds.right,
        order: 0,
      ),
      WidgetInstanceConfig(
        instanceId: 'planning_habits',
        pluginId: 'habits',
        regionId: DashboardRegionIds.right,
        order: 1,
      ),
      WidgetInstanceConfig(
        instanceId: 'planning_quick_actions',
        pluginId: 'quick_actions',
        regionId: DashboardRegionIds.right,
        order: 2,
      ),
    ],
  );
}
