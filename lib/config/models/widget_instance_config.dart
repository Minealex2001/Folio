import 'package:json_annotation/json_annotation.dart';

import '../json_schema_version.dart';

part 'widget_instance_config.g.dart';

/// Una instancia colocada de un plugin de widget del catálogo (Fase 4) en
/// una región de dashboard. `settings` es opaco para el motor — cada plugin
/// decide su propia forma, el motor solo la persiste.
@JsonSerializable()
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
    );
  }
}
