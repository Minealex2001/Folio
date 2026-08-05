import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'config_paths.dart';
import 'config_store_backend.dart';
import 'json_schema_version.dart';
import 'models/accessibility_config.dart';
import 'models/dashboard_config.dart';
import 'models/design_tokens.dart';
import 'models/design_variables.dart';
import 'models/layout_config.dart';
import 'models/theme_config.dart';

/// Metadatos ligeros de un documento guardado, para pickers de presets sin
/// tener que deserializar el documento completo.
class ConfigSummary {
  const ConfigSummary({required this.id, required this.name});

  final String id;
  final String name;
}

/// Fachada de persistencia para toda la configuración de personalización
/// (layouts, temas, dashboards). Envuelve [ConfigStoreBackend] (nativo/web)
/// añadiendo serialización JSON tipada y migración de esquema.
///
/// Cada categoría expone un [ValueNotifier] de "revisión" que se incrementa
/// en cada escritura, para que capas reactivas (LayoutEngineController,
/// ThemeConfigController — Fase 2/3) puedan escuchar granularmente en vez de
/// un `ChangeNotifier` monolítico.
class ConfigStore {
  ConfigStore._(this._backend);

  final ConfigStoreBackend _backend;

  final Map<ConfigCategory, ValueNotifier<int>> revisions = {
    for (final category in ConfigCategory.values) category: ValueNotifier<int>(0),
  };

  static Future<ConfigStore> open() async {
    return ConfigStore._(ConfigStoreBackend.instance);
  }

  void _bumpRevision(ConfigCategory category) {
    final notifier = revisions[category]!;
    notifier.value = notifier.value + 1;
  }

  Map<String, dynamic> _decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return runMigrations(
      json,
      kFolioConfigSchemaVersion,
      registry: kFolioConfigMigrations,
    );
  }

  // ── Layouts ────────────────────────────────────────────────────────────

  Future<LayoutConfig?> loadLayout(String id) async {
    final raw = await _backend.read(ConfigCategory.layouts, id);
    if (raw == null) return null;
    return LayoutConfig.fromJson(_decode(raw));
  }

  Future<void> saveLayout(LayoutConfig config) async {
    await _backend.write(
      ConfigCategory.layouts,
      config.id,
      jsonEncode(config.toJson()),
    );
    _bumpRevision(ConfigCategory.layouts);
  }

  Future<List<String>> listLayoutIds() => _backend.listIds(ConfigCategory.layouts);

  Future<void> deleteLayout(String id) async {
    await _backend.delete(ConfigCategory.layouts, id);
    _bumpRevision(ConfigCategory.layouts);
  }

  // ── Themes ─────────────────────────────────────────────────────────────

  Future<ThemeConfig?> loadTheme(String id) async {
    final raw = await _backend.read(ConfigCategory.themes, id);
    if (raw == null) return null;
    return ThemeConfig.fromJson(_decode(raw));
  }

  Future<void> saveTheme(ThemeConfig config) async {
    await _backend.write(
      ConfigCategory.themes,
      config.id,
      jsonEncode(config.toJson()),
    );
    _bumpRevision(ConfigCategory.themes);
  }

  Future<List<String>> listThemeIds() => _backend.listIds(ConfigCategory.themes);

  Future<void> deleteTheme(String id) async {
    await _backend.delete(ConfigCategory.themes, id);
    _bumpRevision(ConfigCategory.themes);
  }

  // ── Dashboards ─────────────────────────────────────────────────────────

  Future<DashboardConfig?> loadDashboard(String id) async {
    final raw = await _backend.read(ConfigCategory.dashboards, id);
    if (raw == null) return null;
    return DashboardConfig.fromJson(_decode(raw));
  }

  Future<void> saveDashboard(DashboardConfig config) async {
    await _backend.write(
      ConfigCategory.dashboards,
      config.id,
      jsonEncode(config.toJson()),
    );
    _bumpRevision(ConfigCategory.dashboards);
  }

  Future<List<String>> listDashboardIds() =>
      _backend.listIds(ConfigCategory.dashboards);

  Future<void> deleteDashboard(String id) async {
    await _backend.delete(ConfigCategory.dashboards, id);
    _bumpRevision(ConfigCategory.dashboards);
  }

  // ── Design Tokens / Variables (Fase 12) ───────────────────────────────

  Future<DesignTokens?> loadTokens(String id) async {
    final raw = await _backend.read(ConfigCategory.tokens, id);
    if (raw == null) return null;
    return DesignTokens.fromJson(_decode(raw));
  }

  Future<void> saveTokens(DesignTokens tokens) async {
    await _backend.write(
      ConfigCategory.tokens,
      tokens.id,
      jsonEncode(tokens.toJson()),
    );
    _bumpRevision(ConfigCategory.tokens);
  }

  Future<List<String>> listTokenIds() => _backend.listIds(ConfigCategory.tokens);

  Future<DesignVariables?> loadVariables(String id) async {
    final raw = await _backend.read(ConfigCategory.variables, id);
    if (raw == null) return null;
    return DesignVariables.fromJson(_decode(raw));
  }

  Future<void> saveVariables(DesignVariables variables) async {
    await _backend.write(
      ConfigCategory.variables,
      variables.id,
      jsonEncode(variables.toJson()),
    );
    _bumpRevision(ConfigCategory.variables);
  }

  Future<List<String>> listVariableIds() =>
      _backend.listIds(ConfigCategory.variables);

  // ── Accesibilidad (Fase 22) ────────────────────────────────────────────
  // Doc singleton — mismo patrón que `_activePackDocId` de más abajo:
  // transversal al usuario, no por-tema/por-layout.

  static const String _accessibilityDocId = 'active';

  Future<AccessibilityConfig?> loadAccessibility() async {
    final raw = await _backend.read(ConfigCategory.accessibility, _accessibilityDocId);
    if (raw == null) return null;
    return AccessibilityConfig.fromJson(_decode(raw));
  }

  Future<void> saveAccessibility(AccessibilityConfig config) async {
    await _backend.write(
      ConfigCategory.accessibility,
      _accessibilityDocId,
      jsonEncode(config.toJson()),
    );
    _bumpRevision(ConfigCategory.accessibility);
  }

  // ── Packs visuales (Fase 8) ────────────────────────────────────────────
  // Solo el id del pack actualmente activo — el contenido de cada pack
  // (theme/layout/dashboard) vive donde ya vive todo lo demás: se aplica
  // directamente a los controllers activos vía `replaceConfig` (ver
  // `VisualPackInstaller`), sin una copia namespaced separada por pack.

  static const String _activePackDocId = 'active';

  Future<String?> loadActivePackId() async {
    final raw = await _backend.read(ConfigCategory.packs, _activePackDocId);
    if (raw == null) return null;
    return (_decode(raw)['packId'] as String?);
  }

  Future<void> saveActivePackId(String? packId) async {
    await _backend.write(
      ConfigCategory.packs,
      _activePackDocId,
      jsonEncode({
        'schemaVersion': kFolioConfigSchemaVersion,
        'packId': packId,
      }),
    );
    _bumpRevision(ConfigCategory.packs);
  }

  // ── Export / Import (hook de Fase 8 — packs visuales) ────────────────────

  Future<String> exportBundle({
    List<String> layoutIds = const [],
    List<String> themeIds = const [],
    List<String> dashboardIds = const [],
  }) async {
    final layouts = <Map<String, dynamic>>[];
    for (final id in layoutIds) {
      final layout = await loadLayout(id);
      if (layout != null) layouts.add(layout.toJson());
    }
    final themes = <Map<String, dynamic>>[];
    for (final id in themeIds) {
      final theme = await loadTheme(id);
      if (theme != null) themes.add(theme.toJson());
    }
    final dashboards = <Map<String, dynamic>>[];
    for (final id in dashboardIds) {
      final dashboard = await loadDashboard(id);
      if (dashboard != null) dashboards.add(dashboard.toJson());
    }
    return jsonEncode({
      'schemaVersion': kFolioConfigSchemaVersion,
      'layouts': layouts,
      'themes': themes,
      'dashboards': dashboards,
    });
  }

  Future<void> importBundle(String json) async {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    for (final raw in (decoded['layouts'] as List? ?? const [])) {
      await saveLayout(LayoutConfig.fromJson(raw as Map<String, dynamic>));
    }
    for (final raw in (decoded['themes'] as List? ?? const [])) {
      await saveTheme(ThemeConfig.fromJson(raw as Map<String, dynamic>));
    }
    for (final raw in (decoded['dashboards'] as List? ?? const [])) {
      await saveDashboard(DashboardConfig.fromJson(raw as Map<String, dynamic>));
    }
  }
}
