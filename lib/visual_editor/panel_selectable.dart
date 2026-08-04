import '../config/models/panel_config.dart';
import '../layout_engine/layout_engine_controller.dart';
import 'selectable.dart';

/// Adapta un panel del motor de layout (Fase 2) a [Selectable]. Sin
/// concepto de color/opacidad/radio de esquina — un panel es solo
/// posición/tamaño/bloqueo.
class PanelSelectable implements Selectable {
  PanelSelectable(this.controller, this.regionId);

  final LayoutEngineController controller;
  final String regionId;

  PanelConfig? get _panel => controller.panelFor(regionId);

  @override
  SelectableKind get kind => SelectableKind.panel;

  @override
  String get id => regionId;

  @override
  double? get width => _panel?.width;

  @override
  double? get height => _panel?.height;

  @override
  double? get x => _panel?.floatingX;

  @override
  double? get y => _panel?.floatingY;

  @override
  bool get locked => _panel?.locked ?? false;

  @override
  int? get colorArgb => null;

  @override
  double? get opacity => null;

  @override
  double? get cornerRadius => null;

  @override
  void setSize({double? width, double? height}) {
    controller.setSize(regionId, width: width, height: height);
  }

  @override
  void setPosition({double? x, double? y}) {
    if (x == null || y == null) return;
    controller.setFloatingPosition(regionId, x, y);
  }

  @override
  void setColorArgb(int? argb) {}

  @override
  void setOpacity(double? opacity) {}

  @override
  void setCornerRadius(double? radius) {}
}
