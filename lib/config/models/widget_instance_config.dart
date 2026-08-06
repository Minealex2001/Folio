import 'package:json_annotation/json_annotation.dart';

import '../json_schema_version.dart';
import 'widget_appearance_config.dart';
import 'widget_capability_overrides.dart';

part 'widget_instance_config.g.dart';

/// Una instancia colocada de un plugin de widget del catálogo (Fase 4) en
/// una región de dashboard. `settings` es opaco para el motor — cada plugin
/// decide su propia forma, el motor solo la persiste.
@JsonSerializable(explicitToJson: true)
class WidgetInstanceConfig {
  WidgetInstanceConfig({
    this.schemaVersion = kFolioConfigSchemaVersion,
    required this.instanceId,
    required this.pluginId,
    required this.regionId,
    this.order = 0,
    this.width,
    this.height,
    this.visible = true,
    this.groupId,
    this.settings = const {},
    this.capabilityOverrides,
    this.appearance,
  });

  final int schemaVersion;

  /// UUID, único por instancia colocada (a diferencia de [pluginId], que
  /// identifica el tipo de widget en el catálogo).
  final String instanceId;
  final String pluginId;
  final String regionId;
  final int order;
  final double? width;
  final double? height;
  final bool visible;

  /// Agrupación de widgets (Fase 5). null = sin grupo.
  final String? groupId;

  final Map<String, dynamic> settings;

  /// Override por-instancia de `FolioWidgetPlugin.capabilities` (Fase 13).
  /// null = usa el default del plugin sin cambios.
  final WidgetCapabilityOverrides? capabilityOverrides;

  /// Configuración visual genérica por-instancia (Fase 31). `null` = sin
  /// override — el fallback a las claves legacy de `settings` vive en
  /// `WidgetInstanceFrame._applyOverrides`, no aquí.
  final WidgetAppearanceConfig? appearance;

  factory WidgetInstanceConfig.fromJson(Map<String, dynamic> json) =>
      _$WidgetInstanceConfigFromJson(json);

  Map<String, dynamic> toJson() => _$WidgetInstanceConfigToJson(this);

  WidgetInstanceConfig copyWith({
    String? regionId,
    int? order,
    double? width,
    double? height,
    bool? visible,
    String? groupId,
    bool clearGroupId = false,
    Map<String, dynamic>? settings,
    WidgetCapabilityOverrides? capabilityOverrides,
    WidgetAppearanceConfig? appearance,
  }) {
    return WidgetInstanceConfig(
      schemaVersion: schemaVersion,
      instanceId: instanceId,
      pluginId: pluginId,
      regionId: regionId ?? this.regionId,
      order: order ?? this.order,
      width: width ?? this.width,
      height: height ?? this.height,
      visible: visible ?? this.visible,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      settings: settings ?? this.settings,
      capabilityOverrides: capabilityOverrides ?? this.capabilityOverrides,
      appearance: appearance ?? this.appearance,
    );
  }
}
