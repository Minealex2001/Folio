import '../../config/models/dashboard_config.dart';
import '../../config/models/widget_instance_config.dart';

/// Plantilla "Research" (Fase 30) — búsqueda, marcadores y una vista de
/// base de datos, con tareas y recientes de apoyo.
DashboardConfig researchDashboardTemplate() {
  return DashboardConfig(
    id: 'template-research',
    name: 'Research',
    columns: 2,
    widgets: [
      WidgetInstanceConfig(
        instanceId: 'research_search',
        pluginId: 'search',
        regionId: DashboardRegionIds.left,
        order: 0,
      ),
      WidgetInstanceConfig(
        instanceId: 'research_bookmarks',
        pluginId: 'bookmarks',
        regionId: DashboardRegionIds.left,
        order: 1,
      ),
      WidgetInstanceConfig(
        instanceId: 'research_tasks',
        pluginId: 'tasks',
        regionId: DashboardRegionIds.left,
        order: 2,
      ),
      WidgetInstanceConfig(
        instanceId: 'research_database',
        pluginId: 'database_view',
        regionId: DashboardRegionIds.right,
        order: 0,
      ),
      WidgetInstanceConfig(
        instanceId: 'research_recents',
        pluginId: 'recents',
        regionId: DashboardRegionIds.right,
        order: 1,
      ),
    ],
  );
}
