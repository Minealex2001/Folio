import 'package:json_annotation/json_annotation.dart';

import '../json_schema_version.dart';

part 'workspace_config.g.dart';

/// Estado de sesión del workspace (Fase 28) — paneles abiertos, dashboard
/// activo, zoom, focus mode, páginas fijadas, panel de IA/colaboración
/// abierto, filtros, pestañas abiertas. Categoría propia de [ConfigStore]
/// (doc singleton `id: 'active'`, mismo patrón que `AccessibilityConfig`)
/// — no es tema ni layout estructural, es "en qué estaba el usuario".
///
/// Absorbe conceptualmente lo que hoy vive disperso en campos `State`
/// efímeros de `workspace_page.dart` (`_zenMode`, ancho/geometría flotante
/// de paneles de IA/colaboración vía `AppSettings`) — este documento es el
/// esquema/persistencia; la migración real de esos campos `State` a leer/
/// escribir aquí es trabajo de UI de seguimiento (mismo tipo de riesgo que
/// la Fase 24, no ejecutado en esta fase).
@JsonSerializable(explicitToJson: true)
class WorkspaceConfig {
  const WorkspaceConfig({
    this.schemaVersion = kFolioConfigSchemaVersion,
    this.id = 'active',
    this.activeDashboardId = 'active',
    this.zoom = 1.0,
    this.focusMode = false,
    this.showToolbar = true,
    this.showBreadcrumbs = true,
    this.showStatusBar = true,
    this.aiPanelOpen = false,
    this.collabPanelOpen = false,
    this.pinnedPageIds = const [],
    this.activePageId,
    this.filters = const {},
    this.openTabs = const [],
    this.activeTabId,
  });

  final int schemaVersion;

  /// 'active' — doc de sesión viva único (no hay múltiples "workspaces"
  /// guardados en v1, a diferencia de layouts/temas/dashboards).
  final String id;

  final String activeDashboardId;
  final double zoom;
  final bool focusMode;
  final bool showToolbar;
  final bool showBreadcrumbs;
  final bool showStatusBar;
  final bool aiPanelOpen;
  final bool collabPanelOpen;
  final List<String> pinnedPageIds;
  final String? activePageId;

  /// Estado de filtro por-vista, opaco para el motor — cada vista decide
  /// su propia forma, igual que `WidgetInstanceConfig.settings`.
  final Map<String, dynamic> filters;

  /// Solo esquema en esta fase — la UI de pestañas es la Fase 29.
  final List<WorkspaceTabEntry> openTabs;
  final String? activeTabId;

  factory WorkspaceConfig.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceConfigFromJson(json);

  Map<String, dynamic> toJson() => _$WorkspaceConfigToJson(this);

  WorkspaceConfig copyWith({
    String? activeDashboardId,
    double? zoom,
    bool? focusMode,
    bool? showToolbar,
    bool? showBreadcrumbs,
    bool? showStatusBar,
    bool? aiPanelOpen,
    bool? collabPanelOpen,
    List<String>? pinnedPageIds,
    String? activePageId,
    bool clearActivePageId = false,
    Map<String, dynamic>? filters,
    List<WorkspaceTabEntry>? openTabs,
    String? activeTabId,
    bool clearActiveTabId = false,
  }) {
    return WorkspaceConfig(
      schemaVersion: schemaVersion,
      id: id,
      activeDashboardId: activeDashboardId ?? this.activeDashboardId,
      zoom: zoom ?? this.zoom,
      focusMode: focusMode ?? this.focusMode,
      showToolbar: showToolbar ?? this.showToolbar,
      showBreadcrumbs: showBreadcrumbs ?? this.showBreadcrumbs,
      showStatusBar: showStatusBar ?? this.showStatusBar,
      aiPanelOpen: aiPanelOpen ?? this.aiPanelOpen,
      collabPanelOpen: collabPanelOpen ?? this.collabPanelOpen,
      pinnedPageIds: pinnedPageIds ?? this.pinnedPageIds,
      activePageId: clearActivePageId ? null : (activePageId ?? this.activePageId),
      filters: filters ?? this.filters,
      openTabs: openTabs ?? this.openTabs,
      activeTabId: clearActiveTabId ? null : (activeTabId ?? this.activeTabId),
    );
  }
}

@JsonSerializable()
class WorkspaceTabEntry {
  const WorkspaceTabEntry({
    required this.pageId,
    this.pinned = false,
    this.order = 0,
  });

  final String pageId;
  final bool pinned;
  final int order;

  factory WorkspaceTabEntry.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceTabEntryFromJson(json);

  Map<String, dynamic> toJson() => _$WorkspaceTabEntryToJson(this);

  WorkspaceTabEntry copyWith({bool? pinned, int? order}) {
    return WorkspaceTabEntry(
      pageId: pageId,
      pinned: pinned ?? this.pinned,
      order: order ?? this.order,
    );
  }
}
