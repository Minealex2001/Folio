import 'package:json_annotation/json_annotation.dart';

part 'panel_config.g.dart';

/// Configuración de una región de panel (sidebar, panel flotante, etc.).
/// Puramente datos — el motor de layout (Fase 2) interpreta estos valores,
/// nunca al revés.
@JsonSerializable()
class PanelConfig {
  PanelConfig({
    required this.regionId,
    this.visible = true,
    this.width,
    this.height,
    this.floatingX,
    this.floatingY,
    this.locked = false,
    this.order = 0,
  });

  final String regionId;
  final bool visible;
  final double? width;
  final double? height;

  /// Posición cuando el panel flota libremente. Ambos null = anclado
  /// (docked) a su posición estructural en el shell.
  final double? floatingX;
  final double? floatingY;

  final bool locked;
  final int order;

  bool get isFloating => floatingX != null && floatingY != null;

  factory PanelConfig.fromJson(Map<String, dynamic> json) =>
      _$PanelConfigFromJson(json);

  Map<String, dynamic> toJson() => _$PanelConfigToJson(this);

  PanelConfig copyWith({
    bool? visible,
    double? width,
    double? height,
    double? floatingX,
    double? floatingY,
    bool? locked,
    int? order,
  }) {
    return PanelConfig(
      regionId: regionId,
      visible: visible ?? this.visible,
      width: width ?? this.width,
      height: height ?? this.height,
      floatingX: floatingX ?? this.floatingX,
      floatingY: floatingY ?? this.floatingY,
      locked: locked ?? this.locked,
      order: order ?? this.order,
    );
  }
}
