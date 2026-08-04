import 'package:json_annotation/json_annotation.dart';

part 'widget_group_config.g.dart';

/// Metadatos de un grupo de widgets del dashboard (Fase 5) — la membresía
/// vive en cada [WidgetInstanceConfig.groupId]; esto solo guarda lo que no
/// es derivable de las instancias individuales (una etiqueta).
@JsonSerializable()
class WidgetGroupConfig {
  WidgetGroupConfig({required this.id, this.label});

  final String id;
  final String? label;

  factory WidgetGroupConfig.fromJson(Map<String, dynamic> json) =>
      _$WidgetGroupConfigFromJson(json);

  Map<String, dynamic> toJson() => _$WidgetGroupConfigToJson(this);

  WidgetGroupConfig copyWith({String? label}) =>
      WidgetGroupConfig(id: id, label: label ?? this.label);
}
