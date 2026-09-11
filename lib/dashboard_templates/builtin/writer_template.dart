import '../../config/models/dashboard_config.dart';
import '../../config/models/widget_instance_config.dart';

/// Plantilla "Writer" (Fase 30) — notas diarias, páginas favoritas y
/// recientes, con reloj a la izquierda.
DashboardConfig writerDashboardTemplate() {
  return DashboardConfig(
    id: 'template-writer',
    name: 'Writer',
    columns: 2,
    widgets: [
      WidgetInstanceConfig(
        instanceId: 'writer_clock',
        pluginId: 'clock',
        regionId: DashboardRegionIds.left,
        order: 0,
        height: 300,
      ),
      WidgetInstanceConfig(
        instanceId: 'writer_daily_notes',
        pluginId: 'daily_notes',
        regionId: DashboardRegionIds.left,
        order: 1,
      ),
      WidgetInstanceConfig(
        instanceId: 'writer_tasks',
        pluginId: 'tasks',
        regionId: DashboardRegionIds.left,
        order: 2,
      ),
      WidgetInstanceConfig(
        instanceId: 'writer_favorite_page',
        pluginId: 'favorite_page',
        regionId: DashboardRegionIds.right,
        order: 0,
      ),
      WidgetInstanceConfig(
        instanceId: 'writer_recents',
        pluginId: 'recents',
        regionId: DashboardRegionIds.right,
        order: 1,
      ),
    ],
  );
}
