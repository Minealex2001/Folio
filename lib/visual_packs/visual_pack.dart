import '../config/models/dashboard_config.dart';
import '../config/models/layout_config.dart';
import '../config/models/theme_config.dart';
import 'visual_pack_manifest.dart';

/// Un pack visual completo: tema + layout + dashboard + metadatos. Es el
/// mismo shape que produce `VisualPackExport` y consume
/// `VisualPackInstaller`/el importador de Settings — un pack builtin
/// (`lib/visual_packs/builtin/`) y un pack exportado por un usuario son
/// indistinguibles una vez parseados.
class VisualPack {
  const VisualPack({
    required this.manifest,
    required this.theme,
    required this.layout,
    required this.dashboard,
  });

  final VisualPackManifest manifest;
  final ThemeConfig theme;
  final LayoutConfig layout;
  final DashboardConfig dashboard;

  factory VisualPack.fromJson(Map<String, dynamic> json) {
    return VisualPack(
      manifest: VisualPackManifest.fromJson(
        json['manifest'] as Map<String, dynamic>,
      ),
      theme: ThemeConfig.fromJson(json['theme'] as Map<String, dynamic>),
      layout: LayoutConfig.fromJson(json['layout'] as Map<String, dynamic>),
      dashboard: DashboardConfig.fromJson(
        json['dashboard'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'manifest': manifest.toJson(),
    'theme': theme.toJson(),
    'layout': layout.toJson(),
    'dashboard': dashboard.toJson(),
  };
}
