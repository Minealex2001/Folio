import 'package:json_annotation/json_annotation.dart';

part 'widget_capability_overrides.g.dart';

/// Override nullable por-instancia de [WidgetCapabilities] — cada campo en
/// `null` significa "hereda el default del plugin"; un valor explícito gana.
@JsonSerializable()
class WidgetCapabilityOverrides {
  const WidgetCapabilityOverrides({
    this.movable,
    this.resizable,
    this.duplicable,
    this.closable,
    this.detachable,
  });

  final bool? movable;
  final bool? resizable;
  final bool? duplicable;
  final bool? closable;
  final bool? detachable;

  factory WidgetCapabilityOverrides.fromJson(Map<String, dynamic> json) =>
      _$WidgetCapabilityOverridesFromJson(json);

  Map<String, dynamic> toJson() => _$WidgetCapabilityOverridesToJson(this);
}
