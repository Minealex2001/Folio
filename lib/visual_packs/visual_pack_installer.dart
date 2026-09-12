import '../layout_engine/layout_engine_controller.dart';
import '../theme_engine/theme_config_controller.dart';
import '../widget_catalog/dnd/dashboard_grid_controller.dart';
import 'active_pack_controller.dart';
import 'visual_pack.dart';

/// Aplica un [VisualPack] a los tres controllers activos en memoria —
/// `replaceConfig` en cada uno conserva la id activa y dispara la
/// persistencia debounced normal, así que instalar un pack no es un camino
/// especial: es la misma escritura que cualquier otra edición de
/// tema/layout/dashboard, solo que reemplaza los tres documentos a la vez.
class VisualPackInstaller {
  const VisualPackInstaller({
    required this.layoutEngineController,
    required this.themeConfigController,
    required this.dashboardGridController,
    required this.activePackController,
  });

  final LayoutEngineController layoutEngineController;
  final ThemeConfigController themeConfigController;
  final DashboardGridController dashboardGridController;
  final ActivePackController activePackController;

  Future<void> apply(VisualPack pack) async {
    layoutEngineController.replaceConfig(pack.layout);
    themeConfigController.replaceConfig(pack.theme);
    dashboardGridController.replaceConfig(pack.dashboard);
    await activePackController.setActivePackId(pack.manifest.id);
  }
}
