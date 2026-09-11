import '../../config/models/dashboard_config.dart';
import '../../config/models/widget_instance_config.dart';

/// Plantilla "Student" (Fase 30) — calendario, tareas, hábitos y notas
/// diarias, con reloj a la izquierda.
DashboardConfig studentDashboardTemplate() {
  return DashboardConfig(
    id: 'template-student',
    name: 'Student',
    columns: 2,
    widgets: [
      WidgetInstanceConfig(
        instanceId: 'student_clock',
        pluginId: 'clock',
        regionId: DashboardRegionIds.left,
        order: 0,
        height: 300,
      ),
      WidgetInstanceConfig(
        instanceId: 'student_calendar',
        pluginId: 'calendar',
        regionId: DashboardRegionIds.left,
        order: 1,
      ),
      WidgetInstanceConfig(
        instanceId: 'student_tasks',
        pluginId: 'tasks',
        regionId: DashboardRegionIds.right,
        order: 0,
      ),
      WidgetInstanceConfig(
        instanceId: 'student_habits',
        pluginId: 'habits',
        regionId: DashboardRegionIds.right,
        order: 1,
      ),
      WidgetInstanceConfig(
        instanceId: 'student_daily_notes',
        pluginId: 'daily_notes',
        regionId: DashboardRegionIds.right,
        order: 2,
      ),
    ],
  );
}
