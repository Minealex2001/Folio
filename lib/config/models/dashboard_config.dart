import 'package:json_annotation/json_annotation.dart';

import '../json_schema_version.dart';
import 'widget_group_config.dart';
import 'widget_instance_config.dart';

part 'dashboard_config.g.dart';

/// IDs de región de dashboard usados por el layout de inicio migrado desde
/// `WorkspaceHomeSectionIds` (Fase 1) — columna izquierda/derecha, igual que
/// hoy. La Fase 4/5 puede introducir regiones adicionales (p. ej. grid
/// libre) sin romper estas dos.
abstract final class DashboardRegionIds {
  static const String left = 'left';
  static const String right = 'right';
}

@JsonSerializable(explicitToJson: true)
class DashboardConfig {
  DashboardConfig({
    this.schemaVersion = kFolioConfigSchemaVersion,
    required this.id,
    required this.name,
    this.columns = 2,
    this.gap = 16,
    this.widgets = const [],
    this.groups = const [],
    this.responsiveOverrides,
  });

  final int schemaVersion;
  final String id;
  final String name;

  /// Mapea directo al ejemplo JSON del brief: `{"dashboard": {"columns": 3,
  /// "gap": 16}}`.
  final int columns;
  final double gap;

  final List<WidgetInstanceConfig> widgets;

  /// Grupos de widgets (Fase 5) — cada [WidgetInstanceConfig.groupId]
  /// apunta a la id de una entrada aquí.
  final List<WidgetGroupConfig> groups;

  /// Overrides parciales por breakpoint (Fase 26, mismo patrón que
  /// `LayoutConfig.responsiveOverrides`). Key = `Breakpoint.name`. Solo se
  /// listan los widgets (`WidgetInstanceConfig`, por `instanceId`) que
  /// difieren de la config base — ej. ocultar un widget en 'mobile'. No
  /// afecta `columns`/`gap` (campos escalares sin representación dispersa
  /// natural, a diferencia de `panels`/`widgets` que son colecciones
  /// indexadas por id).
  final Map<String, DashboardConfig>? responsiveOverrides;

  factory DashboardConfig.fromJson(Map<String, dynamic> json) =>
      _$DashboardConfigFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardConfigToJson(this);

  DashboardConfig copyWith({
    String? name,
    int? columns,
    double? gap,
    List<WidgetInstanceConfig>? widgets,
    List<WidgetGroupConfig>? groups,
    Map<String, DashboardConfig>? responsiveOverrides,
  }) {
    return DashboardConfig(
      schemaVersion: schemaVersion,
      id: id,
      name: name ?? this.name,
      columns: columns ?? this.columns,
      gap: gap ?? this.gap,
      widgets: widgets ?? this.widgets,
      groups: groups ?? this.groups,
      responsiveOverrides: responsiveOverrides ?? this.responsiveOverrides,
    );
  }
}
