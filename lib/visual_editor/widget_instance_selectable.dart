import '../config/models/widget_instance_config.dart';
import '../widget_catalog/dnd/dashboard_grid_controller.dart';
import 'selectable.dart';

/// Adapta una instancia de widget del dashboard (Fase 5) a [Selectable].
///
/// Color/opacidad/radio de esquina se guardan en
/// `WidgetInstanceConfig.settings` (`colorOverrideArgb`/`opacityOverride`/
/// `cornerRadiusOverride`) — un override a nivel de INSTANCIA, no del
/// `ThemeConfig` global. Es el mecanismo que mantiene "tema" y "override
/// visual por elemento" separados: editar un widget no redefine el tema
/// para toda la app (ver Fase 3 — separación estricta tema/layout, y aquí,
/// tema/instancia).
class WidgetInstanceSelectable implements Selectable {
  WidgetInstanceSelectable(this.controller, this.instanceId);

  final DashboardGridController controller;
  final String instanceId;

  static const _colorKey = 'colorOverrideArgb';
  static const _opacityKey = 'opacityOverride';
  static const _cornerRadiusKey = 'cornerRadiusOverride';

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
    final raw = _instance?.settings[_colorKey];
    return raw is int ? raw : null;
  }

  @override
  double? get opacity {
    final raw = _instance?.settings[_opacityKey];
    return raw is num ? raw.toDouble() : null;
  }

  @override
  double? get cornerRadius {
    final raw = _instance?.settings[_cornerRadiusKey];
    return raw is num ? raw.toDouble() : null;
  }

  @override
  void setSize({double? width, double? height}) {
    controller.resizeInstance(instanceId, width: width, height: height);
  }

  @override
  void setPosition({double? x, double? y}) {}

  @override
  void setColorArgb(int? argb) => _setSetting(_colorKey, argb);

  @override
  void setOpacity(double? opacity) => _setSetting(_opacityKey, opacity);

  @override
  void setCornerRadius(double? radius) => _setSetting(_cornerRadiusKey, radius);

  void _setSetting(String key, Object? value) {
    final instance = _instance;
    if (instance == null) return;
    final next = Map<String, dynamic>.from(instance.settings);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    controller.setInstanceSettings(instanceId, next);
  }
}
