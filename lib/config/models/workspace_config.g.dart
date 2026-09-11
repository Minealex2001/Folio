// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkspaceConfig _$WorkspaceConfigFromJson(Map<String, dynamic> json) =>
    WorkspaceConfig(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? kFolioConfigSchemaVersion,
      id: json['id'] as String? ?? 'active',
      activeDashboardId: json['activeDashboardId'] as String? ?? 'active',
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
      focusMode: json['focusMode'] as bool? ?? false,
      showToolbar: json['showToolbar'] as bool? ?? true,
      showBreadcrumbs: json['showBreadcrumbs'] as bool? ?? true,
      showStatusBar: json['showStatusBar'] as bool? ?? true,
      aiPanelOpen: json['aiPanelOpen'] as bool? ?? false,
      collabPanelOpen: json['collabPanelOpen'] as bool? ?? false,
      pinnedPageIds:
          (json['pinnedPageIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      activePageId: json['activePageId'] as String?,
      filters: json['filters'] as Map<String, dynamic>? ?? const {},
      openTabs:
          (json['openTabs'] as List<dynamic>?)
              ?.map(
                (e) => WorkspaceTabEntry.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      activeTabId: json['activeTabId'] as String?,
    );

Map<String, dynamic> _$WorkspaceConfigToJson(WorkspaceConfig instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'id': instance.id,
      'activeDashboardId': instance.activeDashboardId,
      'zoom': instance.zoom,
      'focusMode': instance.focusMode,
      'showToolbar': instance.showToolbar,
      'showBreadcrumbs': instance.showBreadcrumbs,
      'showStatusBar': instance.showStatusBar,
      'aiPanelOpen': instance.aiPanelOpen,
      'collabPanelOpen': instance.collabPanelOpen,
      'pinnedPageIds': instance.pinnedPageIds,
      'activePageId': instance.activePageId,
      'filters': instance.filters,
      'openTabs': instance.openTabs.map((e) => e.toJson()).toList(),
      'activeTabId': instance.activeTabId,
    };

WorkspaceTabEntry _$WorkspaceTabEntryFromJson(Map<String, dynamic> json) =>
    WorkspaceTabEntry(
      pageId: json['pageId'] as String,
      pinned: json['pinned'] as bool? ?? false,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$WorkspaceTabEntryToJson(WorkspaceTabEntry instance) =>
    <String, dynamic>{
      'pageId': instance.pageId,
      'pinned': instance.pinned,
      'order': instance.order,
    };
