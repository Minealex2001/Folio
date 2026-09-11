import 'package:json_annotation/json_annotation.dart';

part 'widget_theme_tokens.g.dart';

/// Tema semántico por-tipo-de-widget (Fase 23) — distinto de
/// `WidgetAppearanceConfig` (Fase 31, configuración visual genérica
/// por-INSTANCIA: color/borde/sombra/radio, misma forma para cualquier
/// widget). Esto vive en [ThemeConfig] (se hereda entre packs/variantes) y
/// cada plugin define sus propias claves con significado propio — ej.
/// `{"calendar": {"weekendColor": "@color.danger"}, "tasks":
/// {"completedOpacity": 0.45}}`.
///
/// También es el mecanismo de **Plugin Theme API**: Folio nunca inspecciona
/// las claves de un mapa concreto — un plugin de terceros (futuro
/// marketplace) puede declarar su propia clase de tema tipada
/// (`class GitHubWidgetTheme {...}`) fuera de este repo, serializarla a un
/// `Map<String, dynamic>` con su propio `toJson()`, y Folio solo transporta
/// y persiste ese mapa sin conocer su forma.
@JsonSerializable()
class WidgetThemeTokens {
  const WidgetThemeTokens({this.widgets = const {}});

  /// pluginId -> mapa de tema opaco específico del plugin. Los valores
  /// pueden ser literales o referencias de token con prefijo '@' — el
  /// plugin decide si los lee crudos o los resuelve vía
  /// `DesignTokensResolver`.
  final Map<String, Map<String, dynamic>> widgets;

  factory WidgetThemeTokens.fromJson(Map<String, dynamic> json) =>
      _$WidgetThemeTokensFromJson(json);

  Map<String, dynamic> toJson() => _$WidgetThemeTokensToJson(this);
}
