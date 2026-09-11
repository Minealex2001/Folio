import '../config/models/widget_appearance_config.dart';
import '../config/models/widget_instance_config.dart';
import '../widget_catalog/dnd/dashboard_grid_controller.dart';
import 'selectable.dart';

/// Adapta una instancia de widget del dashboard (Fase 5) a [Selectable].
///
/// Color/opacidad/radio de esquina se guardan en
/// `WidgetInstanceConfig.appearance` (Fase 31, `WidgetAppearanceConfig`
/// tipado) — un override a nivel de INSTANCIA, no del `ThemeConfig` global.
/// Es el mecanismo que mantiene "tema" y "override visual por elemento"
/// separados: editar un widget no redefine el tema para toda la app (ver
/// Fase 3 — separación estricta tema/layout, y aquí, tema/instancia).
///
/// Antes de la Fase 31 estos tres valores vivían en el mapa opaco
/// `settings` (`colorOverrideArgb`/`opacityOverride`/`cornerRadiusOverride`)
/// — los getters siguen leyendo esas claves como fallback para instancias
/// ya guardadas con el formato antiguo; los setters escriben solo al campo
/// tipado nuevo de aquí en adelante.
class WidgetInstanceSelectable implements Selectable {
  WidgetInstanceSelectable(this.controller, this.instanceId);

  final DashboardGridController controller;
  final String instanceId;

  static const _legacyColorKey = 'colorOverrideArgb';
  static const _legacyOpacityKey = 'opacityOverride';
  static const _legacyCornerRadiusKey = 'cornerRadiusOverride';

  WidgetInstanceConfig? get _instance => controller.instanceFor(instanceId);

  @override
  SelectableKind get kind => SelectableKind.widgetInstance;

  @override
  String get id => instanceId;

  @override
  double? get width => _instance?.width;

  @override
  double? get height => _instance?.height;

  /// v1: las instancias de dashboard siguen el flujo de columnas (Fase 5),
  /// sin posición libre — ver `DashboardGridController.moveToColumn`.
  @override
  double? get x => null;

  @override
  double? get y => null;

  @override
  bool get locked => false;

  @override
  int? get colorArgb {
    final typed = _instance?.appearance?.backgroundColorArgb;
    if (typed != null) return typed;
    final raw = _instance?.settings[_legacyColorKey];
    return raw is int ? raw : null;
  }

  @override
  double? get opacity {
    final typed = _instance?.appearance?.opacity;
    if (typed != null) return typed;
    final raw = _instance?.settings[_legacyOpacityKey];
    return raw is num ? raw.toDouble() : null;
  }

  @override
  double? get cornerRadius {
    final typed = _instance?.appearance?.cornerRadius;
    if (typed != null) return typed;
    final raw = _instance?.settings[_legacyCornerRadiusKey];
    return raw is num ? raw.toDouble() : null;
  }

  @override
  void setSize({double? width, double? height}) {
    controller.resizeInstance(instanceId, width: width, height: height);
  }

  @override
  void setPosition({double? x, double? y}) {}

  @override
  void setColorArgb(int? argb) => _setAppearance(
    (a) => a.copyWith(
      backgroundColorArgb: argb,
      clearBackgroundColorArgb: argb == null,
    ),
  );

  @override
  void setOpacity(double? opacity) =>
      _setAppearance((a) => a.copyWith(opacity: opacity, clearOpacity: opacity == null));

  @override
  void setCornerRadius(double? radius) => _setAppearance(
    (a) => a.copyWith(cornerRadius: radius, clearCornerRadius: radius == null),
  );

  void _setAppearance(
    WidgetAppearanceConfig Function(WidgetAppearanceConfig current) update,
  ) {
    final instance = _instance;
    if (instance == null) return;
    final current = instance.appearance ?? const WidgetAppearanceConfig();
    controller.setInstanceAppearance(instanceId, update(current));
  }
}
