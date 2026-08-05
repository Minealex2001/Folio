import 'dart:convert';

import '../layout_engine/layout_engine_controller.dart';
import '../theme_engine/theme_config_controller.dart';
import '../widget_catalog/dnd/dashboard_grid_controller.dart';
import 'visual_pack.dart';
import 'visual_pack_manifest.dart';

/// Empaqueta el tema/layout/dashboard actualmente activos (en memoria, no
/// releídos de disco) en un [VisualPack] exportable — el inverso de
/// `VisualPackInstaller.apply`. Cumple el "totalmente exportable" del brief
/// sin requerir una carpeta visible: el usuario elige dónde guardar el
/// archivo JSON resultante.
class VisualPackExport {
  const VisualPackExport({
    required this.layoutEngineController,
    required this.themeConfigController,
    required this.dashboardGridController,
  });

  final LayoutEngineController layoutEngineController;
  final ThemeConfigController themeConfigController;
  final DashboardGridController dashboardGridController;

  VisualPack buildPack({
    required String id,
    required String name,
    String? author,
    String description = '',
  }) {
    return VisualPack(
      manifest: VisualPackManifest(
        id: id,
        name: name,
        description: description,
        author: author,
      ),
      theme: themeConfigController.config,
      layout: layoutEngineController.config,
      dashboard: dashboardGridController.config,
    );
  }

  /// JSON con indentación legible — este es el mismo formato que un pack
  /// builtin produce al serializarse, y el que `VisualPack.fromJson` espera
  /// al reimportar.
  String exportAsJson({
    required String id,
    required String name,
    String? author,
    String description = '',
  }) {
    final pack = buildPack(
      id: id,
      name: name,
      author: author,
      description: description,
    );
    return const JsonEncoder.withIndent('  ').convert(pack.toJson());
  }
}
