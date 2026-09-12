import 'package:json_annotation/json_annotation.dart';

import '../json_schema_version.dart';

part 'design_variables.g.dart';

/// Relaciones con nombre entre tokens (o entre variables), no valores en sí
/// — el punto 6 del brief: `space.md -> editor.padding -> sidebar.padding ->
/// toolbar.padding`. Cada entrada es un string de referencia con el mismo
/// formato de cable que [TokenRef] (prefijo `@`), así que una variable puede
/// apuntar a un token (`"@radius.lg"`) o a otra variable
/// (`"@var.editorPadding"`) — [DesignTokensResolver] resuelve ambos casos
/// con el mismo mecanismo.
@JsonSerializable(explicitToJson: true)
class DesignVariables {
  DesignVariables({
    this.schemaVersion = kFolioConfigSchemaVersion,
    this.id = 'default',
    this.entries = const {},
  });

  final int schemaVersion;
  final String id;

  /// nombre -> string de referencia, ej. `{"editorPadding": "@space.md"}`.
  final Map<String, String> entries;

  factory DesignVariables.fromJson(Map<String, dynamic> json) =>
      _$DesignVariablesFromJson(json);

  Map<String, dynamic> toJson() => _$DesignVariablesToJson(this);

  DesignVariables copyWith({Map<String, String>? entries}) {
    return DesignVariables(
      schemaVersion: schemaVersion,
      id: id,
      entries: entries ?? this.entries,
    );
  }
}
