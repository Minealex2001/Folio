import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'folio_build_flags.dart';
import 'folio_in_app_shortcuts.dart';
import '../services/updater/update_release_channel.dart';

enum AiProvider { none, ollama, lmStudio, folioCloud }

/// Ollama y LM Studio solo en escritorio y web; en Android/iOS Quill usa Folio Cloud.
bool get aiLocalProvidersSupported {
  if (kIsWeb) return true;
  return defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS;
}

enum AiEndpointMode { localhostOnly, allowRemote }

class CustomIconEntry {
  const CustomIconEntry({
    required this.id,
    required this.label,
    required this.source,
    required this.filePath,
    required this.mimeType,
    required this.createdAtMs,
  });

  final String id;
  final String label;
  final String source;
  final String filePath;
  final String mimeType;
  final int createdAtMs;

  String get token => 'custom_icon:$id';
  bool get isSvg => mimeType.toLowerCase().contains('svg');

  factory CustomIconEntry.fromJson(Map raw) {
    return CustomIconEntry(
      id: (raw['id'] as String? ?? '').trim(),
      label: (raw['label'] as String? ?? '').trim(),
      source: (raw['source'] as String? ?? '').trim(),
      filePath: (raw['filePath'] as String? ?? '').trim(),
      mimeType: (raw['mimeType'] as String? ?? '').trim(),
      createdAtMs: (raw['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'label': label,
      'source': source,
      'filePath': filePath,
      'mimeType': mimeType,
      'createdAtMs': createdAtMs,
    };
  }

  CustomIconEntry copyWith({
    String? id,
    String? label,
    String? source,
    String? filePath,
    String? mimeType,
    int? createdAtMs,
  }) {
    return CustomIconEntry(
      id: id ?? this.id,
      label: label ?? this.label,
      source: source ?? this.source,
      filePath: filePath ?? this.filePath,
      mimeType: mimeType ?? this.mimeType,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }
}

class IntegrationAppApproval {
  const IntegrationAppApproval({
    required this.appId,
    required this.appName,
    required this.appVersion,
    required this.integrationVersion,
    required this.approvedAtMs,
  });

  final String appId;
  final String appName;
  final String appVersion;
  final String integrationVersion;
  final int approvedAtMs;

  factory IntegrationAppApproval.fromStored(String appId, Object? raw) {
    final safeAppId = appId.trim();
    if (raw is String) {
      return IntegrationAppApproval(
        appId: safeAppId,
        appName: raw.trim().isEmpty ? safeAppId : raw.trim(),
        appVersion: '',
        integrationVersion: '',
        approvedAtMs: 0,
      );
    }
    if (raw is Map) {
      final appName = (raw['appName'] as String? ?? '').trim();
      final appVersion = (raw['appVersion'] as String? ?? '').trim();
      final integrationVersion = (raw['integrationVersion'] as String? ?? '')
          .trim();
      final approvedAtRaw = raw['approvedAtMs'];
      final approvedAtMs = approvedAtRaw is num ? approvedAtRaw.toInt() : 0;
      return IntegrationAppApproval(
        appId: safeAppId,
        appName: appName.isEmpty ? safeAppId : appName,
        appVersion: appVersion,
        integrationVersion: integrationVersion,
        approvedAtMs: approvedAtMs,
      );
    }
    return IntegrationAppApproval(
      appId: safeAppId,
      appName: safeAppId,
      appVersion: '',
      integrationVersion: '',
      approvedAtMs: 0,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'appName': appName,
      'appVersion': appVersion,
      'integrationVersion': integrationVersion,
      'approvedAtMs': approvedAtMs,
    };
  }

  bool matches({required String integrationVersion}) {
    return _normalize(this.integrationVersion) ==
        _normalize(integrationVersion);
  }

  static String _normalize(String value) => value.trim();
}

/// Preferencias de la app persistidas (p. ej. tema). No se borran al eliminar la libreta.
class AppSettings extends ChangeNotifier {
  AppSettings({String integrationSecret = ''})
    : _configuredIntegrationSecret = integrationSecret.trim();

  static const _themeModeKey = 'folio_theme_mode';
  static const _localeCodeKey = 'folio_locale_code';
  static const _vaultIdleLockMinutesKey = 'folio_vault_idle_lock_minutes';
  static const _vaultLockOnMinimizeKey = 'folio_vault_lock_on_minimize';
  static const _enableGlobalSearchHotkeyKey =
      'folio_enable_global_search_hotkey';
  static const _globalSearchHotkeyKey = 'folio_global_search_hotkey';
  static const _minimizeToTrayKey = 'folio_minimize_to_tray';
  static const _closeToTrayKey = 'folio_close_to_tray';
  static const _aiEnabledKey = 'folio_ai_enabled';
  static const _aiProviderKey = 'folio_ai_provider';
  static const _aiBaseUrlKey = 'folio_ai_base_url';
  static const _aiModelKey = 'folio_ai_model';
  static const _aiTimeoutMsKey = 'folio_ai_timeout_ms';
  static const _aiEndpointModeKey = 'folio_ai_endpoint_mode';
  static const _aiRemoteEndpointConfirmedKey =
      'folio_ai_remote_endpoint_confirmed';
  static const _aiAlwaysShowThoughtKey = 'folio_ai_always_show_thought';
  static const _aiLaunchProviderWithAppKey =
      'folio_ai_launch_provider_with_app';
  static const _aiContextWindowTokensKey = 'folio_ai_context_window_tokens';
  static const _aiModelsPrefix = 'folio_ai_models_';
  static const _hasSeenQuillIntroKey = 'folio_has_seen_quill_intro';
  static const _hasSeenQuillWorkspaceTourKey =
      'folio_has_seen_quill_workspace_tour';
  static const _hasAcceptedQuillGlobalScopeKey =
      'folio_has_accepted_quill_global_scope';
  static const _hasCompletedQuillSetupKey = 'folio_has_completed_quill_setup';
  static const _updateReleaseChannelKey = 'folio_update_release_channel';
  static const _betaBannerDismissedKey = 'folio_beta_banner_dismissed';
  static const _inAppShortcutsKey = 'folio_in_app_shortcuts_json';
  static const _approvedIntegrationAppsKey = 'folio_approved_integration_apps';
  static const _editorContentWidthKey = 'folio_editor_content_width';
  static const _workspaceSidebarWidthKey = 'folio_workspace_sidebar_width';
  static const _workspaceSidebarCollapsedKey =
      'folio_workspace_sidebar_collapsed';
  static const _workspaceSidebarAutoRevealKey =
      'folio_workspace_sidebar_auto_reveal';
  static const _workspacePageOutlineVisibleKey =
      'folio_workspace_page_outline_visible';
  static const _customIconsKey = 'folio_custom_icons_v1';
  static const _integrationCustomIconsKey =
      'folio_integration_custom_icons_by_app_v1';
  static const _enterCreatesNewBlockKey = 'folio_enter_creates_new_block';
  static const _syncEnabledKey = 'folio_device_sync_enabled';
  static const _syncRelayEnabledKey = 'folio_device_sync_relay_enabled';
  static const _syncDeviceIdKey = 'folio_device_sync_device_id';
  static const _syncDeviceNameKey = 'folio_device_sync_device_name';
  static const _syncPendingConflictsKey = 'folio_device_sync_pending_conflicts';
  static const _syncLastSuccessMsKey = 'folio_device_sync_last_success_ms';
  static const _recentSearchQueriesKey = 'folio_recent_search_queries_v1';
  static const _scheduledVaultBackupEnabledKey =
      'folio_scheduled_vault_backup_enabled';
  static const _scheduledVaultBackupIntervalHoursKey =
      'folio_scheduled_vault_backup_interval_hours';
  static const _scheduledVaultBackupDirectoryKey =
      'folio_scheduled_vault_backup_directory';
  static const _lastScheduledVaultBackupMsKey =
      'folio_last_scheduled_vault_backup_ms';
  static const _scheduledVaultBackupAlsoUploadCloudKey =
      'folio_scheduled_vault_backup_also_cloud_v1';
  static const int maxRecentSearchQueries = 10;
  static const int defaultScheduledVaultBackupIntervalHours = 24;
  static const int defaultVaultIdleLockMinutes = 15;
  static const String defaultGlobalSearchHotkey = 'Ctrl+Shift+K';
  static const int defaultAiTimeoutMs = 30000;
  static const String defaultOllamaUrl = 'http://127.0.0.1:11434';
  static const String defaultLmStudioUrl = 'http://127.0.0.1:1234';
  static const String defaultOllamaModel = 'llama3.1:8b';
  static const String defaultLmStudioModel = 'local-model';
  static const int defaultAiContextWindowTokens = 131072;
  static const double minEditorContentWidth = 840;
  static const double maxEditorContentWidth = 1400;
  static const double defaultEditorContentWidth = 1080;
  static const double minWorkspaceSidebarWidth = 220;
  static const double maxWorkspaceSidebarWidth = 480;
  static const double defaultWorkspaceSidebarWidth = 320;
  static const String defaultUpdaterGithubOwner = 'Minealex2001';
  static const String defaultUpdaterGithubRepo = 'Folio';
  static const bool defaultCheckUpdatesOnStartup = true;
  static const UpdateReleaseChannel defaultUpdateReleaseChannel =
      UpdateReleaseChannel.stable;

  /// Portal Folio (vinculación cuenta web). Puede sustituirse con [folioWebPortalBaseUrlFromEnvironment].
  static const String defaultFolioWebPortalBaseUrl =
      'http://localhost:3001/';

  /// Si no está vacío, sustituye a [defaultFolioWebPortalBaseUrl] (p. ej. staging vía `--dart-define`).
  static final String folioWebPortalBaseUrlFromEnvironment =
      const String.fromEnvironment('FOLIO_WEB_PORTAL_BASE_URL').trim();

  /// UI y llamadas al portal para vincular la cuenta web. **Desactivado por defecto.**
  /// Activa con `--dart-define=FOLIO_WEB_PORTAL_LINK_ENABLED=true`.
  static const bool folioWebPortalLinkEnabled = bool.fromEnvironment(
    'FOLIO_WEB_PORTAL_LINK_ENABLED',
    defaultValue: false,
  );

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  int _vaultIdleLockMinutes = defaultVaultIdleLockMinutes;
  bool _vaultLockOnMinimize = false;
  bool _enableGlobalSearchHotkey = true;
  String _globalSearchHotkey = defaultGlobalSearchHotkey;
  bool _minimizeToTray = true;
  bool _closeToTray = true;
  bool _aiEnabled = false;
  AiProvider _aiProvider = AiProvider.none;
  String _aiBaseUrl = defaultOllamaUrl;
  String _aiModel = defaultOllamaModel;
  int _aiTimeoutMs = defaultAiTimeoutMs;
  AiEndpointMode _aiEndpointMode = AiEndpointMode.localhostOnly;
  bool _aiRemoteEndpointConfirmed = false;
  bool _aiAlwaysShowThought = false;
  bool _aiLaunchProviderWithApp = false;
  int _aiContextWindowTokens = defaultAiContextWindowTokens;
  final Map<AiProvider, List<String>> _cachedAiModelsByProvider = {};
  bool _hasSeenQuillIntro = false;
  bool _hasSeenQuillWorkspaceTour = false;
  bool _hasAcceptedQuillGlobalScope = false;
  bool _hasCompletedQuillSetup = false;
  UpdateReleaseChannel _updateReleaseChannel = defaultUpdateReleaseChannel;
  bool _betaBannerDismissed = false;
  double _editorContentWidth = defaultEditorContentWidth;
  double _workspaceSidebarWidth = defaultWorkspaceSidebarWidth;
  bool _workspaceSidebarCollapsed = false;
  bool _workspaceSidebarAutoReveal = false;
  bool _workspacePageOutlineVisible = true;
  Map<FolioInAppShortcut, SingleActivator> _inAppShortcuts =
      defaultShortcutMap();
  final String _configuredIntegrationSecret;
  String _integrationSecret = '';
  Map<String, IntegrationAppApproval> _approvedIntegrationApps = {};
  List<CustomIconEntry> _customIcons = const <CustomIconEntry>[];
  Map<String, List<CustomIconEntry>> _integrationCustomIconsByApp =
      const <String, List<CustomIconEntry>>{};
  bool _enterCreatesNewBlock = true;
  bool _syncEnabled = true;
  bool _syncRelayEnabled = true;
  String _syncDeviceId = '';
  String _syncDeviceName = '';
  int _syncPendingConflicts = 0;
  int _syncLastSuccessMs = 0;
  List<String> _recentSearchQueries = const [];
  bool _scheduledVaultBackupEnabled = false;
  int _scheduledVaultBackupIntervalHours =
      defaultScheduledVaultBackupIntervalHours;
  String _scheduledVaultBackupDirectory = '';
  int _lastScheduledVaultBackupMs = 0;
  bool _scheduledVaultBackupAlsoUploadCloud = false;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  int get vaultIdleLockMinutes => _vaultIdleLockMinutes;
  bool get vaultLockOnMinimize => _vaultLockOnMinimize;
  bool get enableGlobalSearchHotkey => _enableGlobalSearchHotkey;
  String get globalSearchHotkey => _globalSearchHotkey;
  bool get minimizeToTray => _minimizeToTray;
  bool get closeToTray => _closeToTray;
  bool get aiEnabled => _aiEnabled;
  AiProvider get aiProvider => _aiProvider;
  String get aiBaseUrl => _aiBaseUrl;
  String get aiModel => _aiModel;
  int get aiTimeoutMs => _aiTimeoutMs;
  AiEndpointMode get aiEndpointMode => _aiEndpointMode;
  bool get aiRemoteEndpointConfirmed => _aiRemoteEndpointConfirmed;
  bool get aiAlwaysShowThought => _aiAlwaysShowThought;
  bool get aiLaunchProviderWithApp => _aiLaunchProviderWithApp;
  int get aiContextWindowTokens => _aiContextWindowTokens;
  bool get isAiAvailable => !kIsWeb;
  bool get isAiRuntimeEnabled => _aiEnabled;
  bool get hasSeenQuillIntro => _hasSeenQuillIntro;
  bool get hasSeenQuillWorkspaceTour => _hasSeenQuillWorkspaceTour;
  bool get hasAcceptedQuillGlobalScope => _hasAcceptedQuillGlobalScope;
  bool get hasCompletedQuillSetup => _hasCompletedQuillSetup;
  String get updaterGithubOwner => defaultUpdaterGithubOwner;
  String get updaterGithubRepo => defaultUpdaterGithubRepo;
  bool get checkUpdatesOnStartup => defaultCheckUpdatesOnStartup;
  UpdateReleaseChannel get updateReleaseChannel => _updateReleaseChannel;
  double get editorContentWidth => _editorContentWidth;
  double get workspaceSidebarWidth => _workspaceSidebarWidth;
  bool get workspaceSidebarCollapsed => _workspaceSidebarCollapsed;
  bool get workspaceSidebarAutoReveal => _workspaceSidebarAutoReveal;
  bool get workspacePageOutlineVisible => _workspacePageOutlineVisible;
  String get integrationSecret => _integrationSecret;
  bool get enterCreatesNewBlock => _enterCreatesNewBlock;
  bool get syncEnabled => _syncEnabled;
  bool get syncRelayEnabled => _syncRelayEnabled;
  String get syncDeviceId => _syncDeviceId;
  String get syncDeviceName =>
      _syncDeviceName.isEmpty ? _defaultSyncDeviceName() : _syncDeviceName;
  int get syncPendingConflicts => _syncPendingConflicts;
  int get syncLastSuccessMs => _syncLastSuccessMs;
  List<String> get recentSearchQueries =>
      List.unmodifiable(_recentSearchQueries);
  bool get scheduledVaultBackupEnabled => _scheduledVaultBackupEnabled;
  int get scheduledVaultBackupIntervalHours =>
      _scheduledVaultBackupIntervalHours;
  String get scheduledVaultBackupDirectory => _scheduledVaultBackupDirectory;
  int get lastScheduledVaultBackupMs => _lastScheduledVaultBackupMs;
  bool get scheduledVaultBackupAlsoUploadCloud =>
      _scheduledVaultBackupAlsoUploadCloud;

  /// URL del portal para vincular cuenta web: [folioWebPortalBaseUrlFromEnvironment] o [defaultFolioWebPortalBaseUrl].
  String get folioWebPortalBaseUrlEffective {
    final env = folioWebPortalBaseUrlFromEnvironment.trim();
    if (env.isNotEmpty) {
      return _normalizeFolioWebPortalBaseUrl(env);
    }
    return _normalizeFolioWebPortalBaseUrl(defaultFolioWebPortalBaseUrl);
  }

  List<CustomIconEntry> get customIcons => List.unmodifiable(_customIcons);
  List<CustomIconEntry> integrationCustomIconsForApp(String appId) {
    final key = appId.trim();
    if (key.isEmpty) return const <CustomIconEntry>[];
    return List.unmodifiable(_integrationCustomIconsByApp[key] ?? const []);
  }

  List<IntegrationAppApproval> get approvedIntegrationAppApprovals =>
      _approvedIntegrationApps.values.toList(growable: false);
  Map<String, String> get approvedIntegrationApps {
    final mapped = <String, String>{};
    for (final entry in _approvedIntegrationApps.entries) {
      mapped[entry.key] = entry.value.appName;
    }
    return Map<String, String>.unmodifiable(mapped);
  }

  /// Aviso BETA en la UI (no forma parte de la libreta). Controlado por [kFolioShowBetaBanner].
  bool get shouldShowBetaBanner =>
      kFolioShowBetaBanner && !_betaBannerDismissed;

  SingleActivator inAppShortcut(FolioInAppShortcut id) =>
      _inAppShortcuts[id] ?? id.defaultActivator;

  String describeInAppShortcut(FolioInAppShortcut id) =>
      describeActivator(inAppShortcut(id));

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_themeModeKey);
    _themeMode = _parseThemeMode(raw) ?? ThemeMode.system;
    final localeCode = p.getString(_localeCodeKey);
    _locale = localeCode == null || localeCode.isEmpty
        ? null
        : Locale(localeCode);
    final idleMinutes = p.getInt(_vaultIdleLockMinutesKey);
    _vaultIdleLockMinutes = (idleMinutes == null || idleMinutes <= 0)
        ? defaultVaultIdleLockMinutes
        : idleMinutes;
    _vaultLockOnMinimize = p.getBool(_vaultLockOnMinimizeKey) ?? false;
    _enableGlobalSearchHotkey = p.getBool(_enableGlobalSearchHotkeyKey) ?? true;
    _globalSearchHotkey =
        p.getString(_globalSearchHotkeyKey) ?? defaultGlobalSearchHotkey;
    _minimizeToTray = p.getBool(_minimizeToTrayKey) ?? true;
    _closeToTray = p.getBool(_closeToTrayKey) ?? true;
    _aiEnabled = p.getBool(_aiEnabledKey) ?? false;
    _aiProvider = _parseAiProvider(p.getString(_aiProviderKey));
    if (!aiLocalProvidersSupported &&
        (_aiProvider == AiProvider.ollama ||
            _aiProvider == AiProvider.lmStudio)) {
      _aiProvider = AiProvider.none;
      await p.setString(_aiProviderKey, _aiProvider.name);
      _aiBaseUrl = defaultUrlForProvider(_aiProvider);
      _aiModel = defaultModelForProvider(_aiProvider);
      await p.setString(_aiBaseUrlKey, _aiBaseUrl);
      await p.setString(_aiModelKey, _aiModel);
    } else {
      _aiBaseUrl =
          p.getString(_aiBaseUrlKey) ?? defaultUrlForProvider(_aiProvider);
      _aiModel = p.getString(_aiModelKey) ?? defaultModelForProvider(_aiProvider);
    }
    _aiTimeoutMs = _sanitizeTimeoutMs(p.getInt(_aiTimeoutMsKey));
    _aiEndpointMode = _parseAiEndpointMode(p.getString(_aiEndpointModeKey));
    _aiRemoteEndpointConfirmed =
        p.getBool(_aiRemoteEndpointConfirmedKey) ?? false;
    _aiAlwaysShowThought = p.getBool(_aiAlwaysShowThoughtKey) ?? false;
    _aiLaunchProviderWithApp = p.getBool(_aiLaunchProviderWithAppKey) ?? false;
    _aiContextWindowTokens = _sanitizeContextWindowTokens(
      p.getInt(_aiContextWindowTokensKey),
    );
    _hasSeenQuillIntro = p.getBool(_hasSeenQuillIntroKey) ?? false;
    _hasSeenQuillWorkspaceTour =
        p.getBool(_hasSeenQuillWorkspaceTourKey) ?? false;
    _hasAcceptedQuillGlobalScope =
        p.getBool(_hasAcceptedQuillGlobalScopeKey) ?? false;
    _hasCompletedQuillSetup = p.getBool(_hasCompletedQuillSetupKey) ?? false;
    _updateReleaseChannel = _parseUpdateReleaseChannel(
      p.getString(_updateReleaseChannelKey),
    );
    _betaBannerDismissed = p.getBool(_betaBannerDismissedKey) ?? false;
    _editorContentWidth = _sanitizeEditorContentWidth(
      p.getDouble(_editorContentWidthKey),
    );
    _workspaceSidebarWidth = _sanitizeWorkspaceSidebarWidth(
      p.getDouble(_workspaceSidebarWidthKey),
    );
    _workspaceSidebarCollapsed =
        p.getBool(_workspaceSidebarCollapsedKey) ?? false;
    _workspaceSidebarAutoReveal =
        p.getBool(_workspaceSidebarAutoRevealKey) ?? false;
    _workspacePageOutlineVisible =
        p.getBool(_workspacePageOutlineVisibleKey) ?? true;
    _inAppShortcuts = parseShortcutOverrides(
      p.getString(_inAppShortcutsKey),
      defaultShortcutMap(),
    );
    _enterCreatesNewBlock = p.getBool(_enterCreatesNewBlockKey) ?? true;
    _syncEnabled = p.getBool(_syncEnabledKey) ?? true;
    _syncRelayEnabled = p.getBool(_syncRelayEnabledKey) ?? true;
    _syncDeviceId = (p.getString(_syncDeviceIdKey) ?? '').trim();
    if (_syncDeviceId.isEmpty) {
      _syncDeviceId = _createSyncDeviceId();
      await p.setString(_syncDeviceIdKey, _syncDeviceId);
    }
    _syncDeviceName = (p.getString(_syncDeviceNameKey) ?? '').trim();
    _syncPendingConflicts = (p.getInt(_syncPendingConflictsKey) ?? 0).clamp(
      0,
      999,
    );
    _syncLastSuccessMs = p.getInt(_syncLastSuccessMsKey) ?? 0;
    _recentSearchQueries = _sanitizeRecentSearchList(
      p.getStringList(_recentSearchQueriesKey),
    );
    _scheduledVaultBackupEnabled =
        p.getBool(_scheduledVaultBackupEnabledKey) ?? false;
    _scheduledVaultBackupIntervalHours = _sanitizeScheduledVaultBackupInterval(
      p.getInt(_scheduledVaultBackupIntervalHoursKey),
    );
    _scheduledVaultBackupDirectory =
        (p.getString(_scheduledVaultBackupDirectoryKey) ?? '').trim();
    _lastScheduledVaultBackupMs = p.getInt(_lastScheduledVaultBackupMsKey) ?? 0;
    _scheduledVaultBackupAlsoUploadCloud =
        p.getBool(_scheduledVaultBackupAlsoUploadCloudKey) ?? false;
    _integrationSecret = _configuredIntegrationSecret;
    final approvedRaw = p.getString(_approvedIntegrationAppsKey);
    if (approvedRaw != null && approvedRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(approvedRaw);
        if (decoded is Map) {
          final parsed = <String, IntegrationAppApproval>{};
          for (final entry in decoded.entries) {
            final key = '${entry.key}';
            parsed[key] = IntegrationAppApproval.fromStored(key, entry.value);
          }
          _approvedIntegrationApps = parsed;
        }
      } catch (_) {
        _approvedIntegrationApps = {};
      }
    } else {
      _approvedIntegrationApps = {};
    }
    final customIconsRaw = p.getString(_customIconsKey);
    if (customIconsRaw != null && customIconsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(customIconsRaw);
        if (decoded is List) {
          _customIcons =
              decoded
                  .whereType<Map>()
                  .map(CustomIconEntry.fromJson)
                  .where(
                    (entry) =>
                        entry.id.isNotEmpty &&
                        entry.filePath.isNotEmpty &&
                        entry.mimeType.isNotEmpty,
                  )
                  .toList(growable: false)
                ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
        }
      } catch (_) {
        _customIcons = const <CustomIconEntry>[];
      }
    } else {
      _customIcons = const <CustomIconEntry>[];
    }
    final integrationCustomIconsRaw = p.getString(_integrationCustomIconsKey);
    if (integrationCustomIconsRaw != null &&
        integrationCustomIconsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(integrationCustomIconsRaw);
        if (decoded is Map) {
          final parsed = <String, List<CustomIconEntry>>{};
          for (final entry in decoded.entries) {
            final appId = '${entry.key}'.trim();
            if (appId.isEmpty || entry.value is! List) continue;
            final icons =
                (entry.value as List)
                    .whereType<Map>()
                    .map(CustomIconEntry.fromJson)
                    .where(
                      (icon) =>
                          icon.id.isNotEmpty &&
                          icon.filePath.isNotEmpty &&
                          icon.mimeType.isNotEmpty,
                    )
                    .toList(growable: false)
                  ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
            parsed[appId] = icons;
          }
          _integrationCustomIconsByApp = parsed;
        }
      } catch (_) {
        _integrationCustomIconsByApp = const <String, List<CustomIconEntry>>{};
      }
    } else {
      _integrationCustomIconsByApp = const <String, List<CustomIconEntry>>{};
    }
    _cachedAiModelsByProvider
      ..clear()
      ..addAll({
        AiProvider.ollama: List<String>.from(
          p.getStringList(_aiModelsKeyForProvider(AiProvider.ollama)) ??
              const <String>[],
        ),
        AiProvider.lmStudio: List<String>.from(
          p.getStringList(_aiModelsKeyForProvider(AiProvider.lmStudio)) ??
              const <String>[],
        ),
        AiProvider.folioCloud: List<String>.from(
          p.getStringList(_aiModelsKeyForProvider(AiProvider.folioCloud)) ??
              const <String>['folio-cloud'],
        ),
      });
    notifyListeners();
  }

  ThemeMode? _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  AiProvider _parseAiProvider(String? raw) {
    switch (raw) {
      case 'ollama':
        return AiProvider.ollama;
      case 'lmStudio':
        return AiProvider.lmStudio;
      case 'folioCloud':
        return AiProvider.folioCloud;
      default:
        return AiProvider.none;
    }
  }

  UpdateReleaseChannel _parseUpdateReleaseChannel(String? raw) {
    return switch (raw) {
      'beta' => UpdateReleaseChannel.beta,
      _ => UpdateReleaseChannel.stable,
    };
  }

  AiEndpointMode _parseAiEndpointMode(String? raw) {
    switch (raw) {
      case 'allowRemote':
        return AiEndpointMode.allowRemote;
      default:
        return AiEndpointMode.localhostOnly;
    }
  }

  int _sanitizeTimeoutMs(int? value) {
    final raw = value ?? defaultAiTimeoutMs;
    if (raw < 3000) return 3000;
    if (raw > 120000) return 120000;
    return raw;
  }

  int _sanitizeContextWindowTokens(int? value) {
    final raw = value ?? defaultAiContextWindowTokens;
    if (raw < 1024) return 1024;
    if (raw > 2000000) return 2000000;
    return raw;
  }

  List<String> _sanitizeRecentSearchList(List<String>? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final out = <String>[];
    for (final s in raw) {
      final t = s.trim();
      if (t.isEmpty) continue;
      if (out.contains(t)) continue;
      out.add(t);
      if (out.length >= maxRecentSearchQueries) break;
    }
    return out;
  }

  int _sanitizeScheduledVaultBackupInterval(int? value) {
    final raw = value ?? defaultScheduledVaultBackupIntervalHours;
    if (raw < 1) return 1;
    if (raw > 168) return 168;
    return raw;
  }

  double _sanitizeEditorContentWidth(double? value) {
    final raw = value ?? defaultEditorContentWidth;
    if (raw < minEditorContentWidth) return minEditorContentWidth;
    if (raw > maxEditorContentWidth) return maxEditorContentWidth;
    return raw;
  }

  double _sanitizeWorkspaceSidebarWidth(double? value) {
    final raw = value ?? defaultWorkspaceSidebarWidth;
    if (raw < minWorkspaceSidebarWidth) return minWorkspaceSidebarWidth;
    if (raw > maxWorkspaceSidebarWidth) return maxWorkspaceSidebarWidth;
    return raw;
  }

  String _defaultSyncDeviceName() {
    if (kIsWeb) return 'Folio Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Folio Android';
      case TargetPlatform.windows:
        return 'Folio Windows';
      case TargetPlatform.linux:
        return 'Folio Linux';
      case TargetPlatform.macOS:
        return 'Folio macOS';
      case TargetPlatform.iOS:
        return 'Folio iOS';
      case TargetPlatform.fuchsia:
        return 'Folio Device';
    }
  }

  String _createSyncDeviceId() {
    final ms = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final platform = defaultTargetPlatform.name;
    return 'dev_${platform}_$ms';
  }

  String defaultUrlForProvider(AiProvider provider) {
    switch (provider) {
      case AiProvider.ollama:
        return defaultOllamaUrl;
      case AiProvider.lmStudio:
        return defaultLmStudioUrl;
      case AiProvider.folioCloud:
        return '';
      case AiProvider.none:
        return defaultOllamaUrl;
    }
  }

  String defaultModelForProvider(AiProvider provider) {
    switch (provider) {
      case AiProvider.ollama:
        return defaultOllamaModel;
      case AiProvider.lmStudio:
        return defaultLmStudioModel;
      case AiProvider.folioCloud:
        return 'folio-cloud';
      case AiProvider.none:
        return defaultOllamaModel;
    }
  }

  String _aiModelsKeyForProvider(AiProvider provider) {
    return '$_aiModelsPrefix${provider.name}';
  }

  List<String> cachedAiModelsFor(AiProvider provider) {
    if (provider == AiProvider.none) return const [];
    return List<String>.from(_cachedAiModelsByProvider[provider] ?? const []);
  }

  Future<void> setCachedAiModelsFor(
    AiProvider provider,
    List<String> models,
  ) async {
    if (provider == AiProvider.none) return;
    final cleaned = models
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    cleaned.sort();
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_aiModelsKeyForProvider(provider), cleaned);
    _cachedAiModelsByProvider[provider] = cleaned;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    final v = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await p.setString(_themeModeKey, v);
  }

  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    final code = locale?.languageCode;
    if (code == null || code.isEmpty) {
      await p.remove(_localeCodeKey);
    } else {
      await p.setString(_localeCodeKey, code);
    }
  }

  Future<void> setVaultIdleLockMinutes(int minutes) async {
    final safe = minutes <= 0 ? defaultVaultIdleLockMinutes : minutes;
    if (_vaultIdleLockMinutes == safe) return;
    _vaultIdleLockMinutes = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_vaultIdleLockMinutesKey, safe);
  }

  Future<void> setVaultLockOnMinimize(bool value) async {
    if (_vaultLockOnMinimize == value) return;
    _vaultLockOnMinimize = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_vaultLockOnMinimizeKey, value);
  }

  Future<void> setEnableGlobalSearchHotkey(bool value) async {
    if (_enableGlobalSearchHotkey == value) return;
    _enableGlobalSearchHotkey = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_enableGlobalSearchHotkeyKey, value);
  }

  Future<void> setGlobalSearchHotkey(String value) async {
    final safe = value.trim().isEmpty
        ? defaultGlobalSearchHotkey
        : value.trim();
    if (_globalSearchHotkey == safe) return;
    _globalSearchHotkey = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_globalSearchHotkeyKey, safe);
  }

  Future<void> setMinimizeToTray(bool value) async {
    if (_minimizeToTray == value) return;
    _minimizeToTray = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_minimizeToTrayKey, value);
  }

  Future<void> setCloseToTray(bool value) async {
    if (_closeToTray == value) return;
    _closeToTray = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_closeToTrayKey, value);
  }

  Future<void> setAiEnabled(bool value) async {
    if (_aiEnabled == value) return;
    _aiEnabled = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_aiEnabledKey, value);
  }

  Future<void> setAiProvider(AiProvider value) async {
    if (!aiLocalProvidersSupported &&
        (value == AiProvider.ollama || value == AiProvider.lmStudio)) {
      return;
    }
    if (_aiProvider == value) return;
    _aiProvider = value;
    if (value == AiProvider.folioCloud) {
      _aiModel = defaultModelForProvider(value);
      notifyListeners();
      final p = await SharedPreferences.getInstance();
      await p.setString(_aiProviderKey, value.name);
      return;
    }
    if (_aiBaseUrl.trim().isEmpty) {
      _aiBaseUrl = defaultUrlForProvider(value);
    }
    if (_aiModel.trim().isEmpty) {
      _aiModel = defaultModelForProvider(value);
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_aiProviderKey, value.name);
  }

  Future<void> setAiBaseUrl(String value) async {
    final safe = value.trim();
    if (safe.isEmpty || _aiBaseUrl == safe) return;
    _aiBaseUrl = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_aiBaseUrlKey, safe);
  }

  static String _normalizeFolioWebPortalBaseUrl(String s) {
    var t = s.trim();
    while (t.endsWith('/')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  Future<void> setAiModel(String value) async {
    final safe = value.trim();
    if (safe.isEmpty || _aiModel == safe) return;
    _aiModel = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_aiModelKey, safe);
  }

  Future<void> setAiTimeoutMs(int value) async {
    final safe = _sanitizeTimeoutMs(value);
    if (_aiTimeoutMs == safe) return;
    _aiTimeoutMs = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_aiTimeoutMsKey, safe);
  }

  Future<void> setAiEndpointMode(AiEndpointMode value) async {
    if (_aiEndpointMode == value) return;
    _aiEndpointMode = value;
    if (value == AiEndpointMode.localhostOnly) {
      _aiRemoteEndpointConfirmed = false;
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_aiEndpointModeKey, value.name);
    if (value == AiEndpointMode.localhostOnly) {
      await p.setBool(_aiRemoteEndpointConfirmedKey, false);
    }
  }

  Future<void> setAiRemoteEndpointConfirmed(bool value) async {
    if (_aiRemoteEndpointConfirmed == value) return;
    _aiRemoteEndpointConfirmed = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_aiRemoteEndpointConfirmedKey, value);
  }

  Future<void> setAiAlwaysShowThought(bool value) async {
    if (_aiAlwaysShowThought == value) return;
    _aiAlwaysShowThought = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_aiAlwaysShowThoughtKey, value);
  }

  Future<void> setAiLaunchProviderWithApp(bool value) async {
    if (_aiLaunchProviderWithApp == value) return;
    _aiLaunchProviderWithApp = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_aiLaunchProviderWithAppKey, value);
  }

  Future<void> setAiContextWindowTokens(int value) async {
    final safe = _sanitizeContextWindowTokens(value);
    if (_aiContextWindowTokens == safe) return;
    _aiContextWindowTokens = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_aiContextWindowTokensKey, safe);
  }

  Future<void> setHasSeenQuillIntro(bool value) async {
    if (_hasSeenQuillIntro == value) return;
    _hasSeenQuillIntro = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_hasSeenQuillIntroKey, value);
  }

  Future<void> setHasSeenQuillWorkspaceTour(bool value) async {
    if (_hasSeenQuillWorkspaceTour == value) return;
    _hasSeenQuillWorkspaceTour = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_hasSeenQuillWorkspaceTourKey, value);
  }

  Future<void> setHasAcceptedQuillGlobalScope(bool value) async {
    if (_hasAcceptedQuillGlobalScope == value) return;
    _hasAcceptedQuillGlobalScope = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_hasAcceptedQuillGlobalScopeKey, value);
  }

  Future<void> setHasCompletedQuillSetup(bool value) async {
    if (_hasCompletedQuillSetup == value) return;
    _hasCompletedQuillSetup = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_hasCompletedQuillSetupKey, value);
  }

  Future<void> setUpdateReleaseChannel(UpdateReleaseChannel value) async {
    if (_updateReleaseChannel == value) return;
    _updateReleaseChannel = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_updateReleaseChannelKey, value.name);
  }

  Future<void> setBetaBannerDismissed(bool value) async {
    if (_betaBannerDismissed == value) return;
    _betaBannerDismissed = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_betaBannerDismissedKey, value);
  }

  Future<void> setEditorContentWidth(double value) async {
    final safe = _sanitizeEditorContentWidth(value);
    if ((_editorContentWidth - safe).abs() < 0.5) return;
    _editorContentWidth = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_editorContentWidthKey, safe);
  }

  Future<void> setWorkspaceSidebarWidth(double value) async {
    final safe = _sanitizeWorkspaceSidebarWidth(value);
    if ((_workspaceSidebarWidth - safe).abs() < 0.5) return;
    _workspaceSidebarWidth = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_workspaceSidebarWidthKey, safe);
  }

  Future<void> setWorkspaceSidebarCollapsed(bool value) async {
    if (_workspaceSidebarCollapsed == value) return;
    _workspaceSidebarCollapsed = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_workspaceSidebarCollapsedKey, value);
  }

  Future<void> setWorkspaceSidebarAutoReveal(bool value) async {
    if (_workspaceSidebarAutoReveal == value) return;
    _workspaceSidebarAutoReveal = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_workspaceSidebarAutoRevealKey, value);
  }

  Future<void> setWorkspacePageOutlineVisible(bool value) async {
    if (_workspacePageOutlineVisible == value) return;
    _workspacePageOutlineVisible = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_workspacePageOutlineVisibleKey, value);
  }

  Future<void> setEnterCreatesNewBlock(bool value) async {
    if (_enterCreatesNewBlock == value) return;
    _enterCreatesNewBlock = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_enterCreatesNewBlockKey, value);
  }

  Future<void> setSyncEnabled(bool value) async {
    if (_syncEnabled == value) return;
    _syncEnabled = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_syncEnabledKey, value);
  }

  Future<void> setSyncRelayEnabled(bool value) async {
    if (_syncRelayEnabled == value) return;
    _syncRelayEnabled = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_syncRelayEnabledKey, value);
  }

  Future<void> setSyncDeviceName(String value) async {
    final safe = value.trim().isEmpty ? _defaultSyncDeviceName() : value.trim();
    if (_syncDeviceName == safe) return;
    _syncDeviceName = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_syncDeviceNameKey, safe);
  }

  Future<void> setSyncPendingConflicts(int value) async {
    final safe = value.clamp(0, 999);
    if (_syncPendingConflicts == safe) return;
    _syncPendingConflicts = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_syncPendingConflictsKey, safe);
  }

  Future<void> setSyncLastSuccessMs(int value) async {
    final safe = value < 0 ? 0 : value;
    if (_syncLastSuccessMs == safe) return;
    _syncLastSuccessMs = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_syncLastSuccessMsKey, safe);
  }

  Future<void> addRecentSearchQuery(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    final next = <String>[q];
    for (final x in _recentSearchQueries) {
      if (x == q) continue;
      next.add(x);
      if (next.length >= maxRecentSearchQueries) break;
    }
    _recentSearchQueries = next;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_recentSearchQueriesKey, _recentSearchQueries);
  }

  Future<void> setScheduledVaultBackupEnabled(bool value) async {
    if (_scheduledVaultBackupEnabled == value) return;
    _scheduledVaultBackupEnabled = value;
    if (value && _lastScheduledVaultBackupMs == 0) {
      _lastScheduledVaultBackupMs = DateTime.now().millisecondsSinceEpoch;
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_scheduledVaultBackupEnabledKey, value);
    if (value && _lastScheduledVaultBackupMs != 0) {
      await p.setInt(_lastScheduledVaultBackupMsKey, _lastScheduledVaultBackupMs);
    }
  }

  Future<void> setScheduledVaultBackupIntervalHours(int value) async {
    final safe = _sanitizeScheduledVaultBackupInterval(value);
    if (_scheduledVaultBackupIntervalHours == safe) return;
    _scheduledVaultBackupIntervalHours = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_scheduledVaultBackupIntervalHoursKey, safe);
  }

  Future<void> setScheduledVaultBackupDirectory(String path) async {
    final safe = path.trim();
    if (_scheduledVaultBackupDirectory == safe) return;
    _scheduledVaultBackupDirectory = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    if (safe.isEmpty) {
      await p.remove(_scheduledVaultBackupDirectoryKey);
    } else {
      await p.setString(_scheduledVaultBackupDirectoryKey, safe);
    }
  }

  Future<void> setLastScheduledVaultBackupMs(int value) async {
    final safe = value < 0 ? 0 : value;
    if (_lastScheduledVaultBackupMs == safe) return;
    _lastScheduledVaultBackupMs = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_lastScheduledVaultBackupMsKey, safe);
  }

  Future<void> setScheduledVaultBackupAlsoUploadCloud(bool value) async {
    if (_scheduledVaultBackupAlsoUploadCloud == value) return;
    _scheduledVaultBackupAlsoUploadCloud = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_scheduledVaultBackupAlsoUploadCloudKey, value);
  }

  Future<void> setInAppShortcut(
    FolioInAppShortcut id,
    SingleActivator activator,
  ) async {
    _inAppShortcuts[id] = activator;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _inAppShortcutsKey,
      serializeShortcutOverrides(_inAppShortcuts),
    );
  }

  Future<void> resetInAppShortcutsToDefaults() async {
    _inAppShortcuts = defaultShortcutMap();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.remove(_inAppShortcutsKey);
  }

  bool isIntegrationAppApproved(String appId, {String? integrationVersion}) {
    final key = appId.trim();
    if (key.isEmpty) return false;
    final approval = _approvedIntegrationApps[key];
    if (approval == null) return false;
    final requiresVersionMatch = integrationVersion?.trim().isNotEmpty ?? false;
    if (!requiresVersionMatch) return true;
    return approval.matches(integrationVersion: integrationVersion ?? '');
  }

  IntegrationAppApproval? integrationAppApproval(String appId) {
    return _approvedIntegrationApps[appId.trim()];
  }

  String integrationAppName(String appId) {
    return _approvedIntegrationApps[appId.trim()]?.appName ?? appId.trim();
  }

  Map<String, Object?> _serializeApprovedIntegrationApps() {
    final serialized = <String, Object?>{};
    for (final entry in _approvedIntegrationApps.entries) {
      serialized[entry.key] = entry.value.toJson();
    }
    return serialized;
  }

  Future<void> approveIntegrationApp({
    required String appId,
    required String appName,
    required String appVersion,
    required String integrationVersion,
  }) async {
    final key = appId.trim();
    if (key.isEmpty) return;
    final label = appName.trim().isEmpty ? key : appName.trim();
    _approvedIntegrationApps[key] = IntegrationAppApproval(
      appId: key,
      appName: label,
      appVersion: appVersion.trim(),
      integrationVersion: integrationVersion.trim(),
      approvedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _approvedIntegrationAppsKey,
      jsonEncode(_serializeApprovedIntegrationApps()),
    );
  }

  Future<void> revokeIntegrationApp(String appId) async {
    final key = appId.trim();
    if (key.isEmpty || !_approvedIntegrationApps.containsKey(key)) return;
    _approvedIntegrationApps.remove(key);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _approvedIntegrationAppsKey,
      jsonEncode(_serializeApprovedIntegrationApps()),
    );
  }

  Future<void> syncApprovedIntegrationAppObservation({
    required String appId,
    required String appName,
    required String appVersion,
    required String integrationVersion,
  }) async {
    final key = appId.trim();
    final current = _approvedIntegrationApps[key];
    if (key.isEmpty || current == null) return;
    if (!current.matches(integrationVersion: integrationVersion)) return;
    final safeName = appName.trim().isEmpty ? key : appName.trim();
    final safeVersion = appVersion.trim();
    if (current.appName == safeName && current.appVersion == safeVersion)
      return;
    _approvedIntegrationApps[key] = IntegrationAppApproval(
      appId: current.appId,
      appName: safeName,
      appVersion: safeVersion,
      integrationVersion: current.integrationVersion,
      approvedAtMs: current.approvedAtMs,
    );
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _approvedIntegrationAppsKey,
      jsonEncode(_serializeApprovedIntegrationApps()),
    );
  }

  bool isCustomIconToken(String? value) {
    final raw = value?.trim() ?? '';
    return raw.startsWith('custom_icon:') && raw.length > 'custom_icon:'.length;
  }

  CustomIconEntry? customIconForToken(String? token) {
    final raw = token?.trim() ?? '';
    if (!isCustomIconToken(raw)) return null;
    final id = raw.substring('custom_icon:'.length).trim();
    if (id.isEmpty) return null;
    for (final icon in _customIcons) {
      if (icon.id == id) return icon;
    }
    return null;
  }

  Future<void> addOrUpdateCustomIcon(CustomIconEntry entry) async {
    final cleaned = entry.copyWith(
      id: entry.id.trim(),
      label: entry.label.trim().isEmpty ? 'Custom icon' : entry.label.trim(),
      source: entry.source.trim(),
      filePath: entry.filePath.trim(),
      mimeType: entry.mimeType.trim(),
    );
    if (cleaned.id.isEmpty ||
        cleaned.filePath.isEmpty ||
        cleaned.mimeType.isEmpty) {
      return;
    }
    final next = List<CustomIconEntry>.from(_customIcons);
    final index = next.indexWhere((icon) => icon.id == cleaned.id);
    if (index >= 0) {
      next[index] = cleaned;
    } else {
      next.add(cleaned);
    }
    next.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    _customIcons = next;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _customIconsKey,
      jsonEncode(_customIcons.map((icon) => icon.toJson()).toList()),
    );
  }

  Future<void> removeCustomIcon(String id) async {
    final key = id.trim();
    if (key.isEmpty) return;
    final next = _customIcons.where((icon) => icon.id != key).toList();
    if (next.length == _customIcons.length) return;
    _customIcons = next;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _customIconsKey,
      jsonEncode(_customIcons.map((icon) => icon.toJson()).toList()),
    );
  }

  Map<String, Object?> _serializeIntegrationCustomIconsByApp() {
    final serialized = <String, Object?>{};
    for (final entry in _integrationCustomIconsByApp.entries) {
      serialized[entry.key] = entry.value.map((icon) => icon.toJson()).toList();
    }
    return serialized;
  }

  Future<void> _persistIntegrationCustomIconsByApp() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _integrationCustomIconsKey,
      jsonEncode(_serializeIntegrationCustomIconsByApp()),
    );
  }

  Future<void> replaceIntegrationCustomIconsForApp(
    String appId,
    List<CustomIconEntry> entries,
  ) async {
    final key = appId.trim();
    if (key.isEmpty) return;
    final cleaned = entries
        .map(
          (entry) => entry.copyWith(
            id: entry.id.trim(),
            label: entry.label.trim().isEmpty
                ? 'Custom icon'
                : entry.label.trim(),
            source: entry.source.trim(),
            filePath: entry.filePath.trim(),
            mimeType: entry.mimeType.trim(),
          ),
        )
        .where(
          (entry) =>
              entry.id.isNotEmpty &&
              entry.filePath.isNotEmpty &&
              entry.mimeType.isNotEmpty,
        )
        .toList();
    cleaned.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    _integrationCustomIconsByApp = {
      ..._integrationCustomIconsByApp,
      key: List<CustomIconEntry>.unmodifiable(cleaned),
    };
    notifyListeners();
    await _persistIntegrationCustomIconsByApp();
  }

  Future<void> addOrUpdateIntegrationCustomIconForApp(
    String appId,
    CustomIconEntry entry,
  ) async {
    final key = appId.trim();
    if (key.isEmpty) return;
    final cleaned = entry.copyWith(
      id: entry.id.trim(),
      label: entry.label.trim().isEmpty ? 'Custom icon' : entry.label.trim(),
      source: entry.source.trim(),
      filePath: entry.filePath.trim(),
      mimeType: entry.mimeType.trim(),
    );
    if (cleaned.id.isEmpty ||
        cleaned.filePath.isEmpty ||
        cleaned.mimeType.isEmpty) {
      return;
    }
    final next = List<CustomIconEntry>.from(
      _integrationCustomIconsByApp[key] ?? const <CustomIconEntry>[],
    );
    final index = next.indexWhere((icon) => icon.id == cleaned.id);
    if (index >= 0) {
      next[index] = cleaned;
    } else {
      next.add(cleaned);
    }
    next.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    _integrationCustomIconsByApp = {
      ..._integrationCustomIconsByApp,
      key: List<CustomIconEntry>.unmodifiable(next),
    };
    notifyListeners();
    await _persistIntegrationCustomIconsByApp();
  }

  Future<void> removeIntegrationCustomIconForApp(
    String appId,
    String id,
  ) async {
    final key = appId.trim();
    final iconId = id.trim();
    if (key.isEmpty || iconId.isEmpty) return;
    final current =
        _integrationCustomIconsByApp[key] ?? const <CustomIconEntry>[];
    final next = current.where((icon) => icon.id != iconId).toList();
    if (next.length == current.length) return;
    final updated = <String, List<CustomIconEntry>>{
      ..._integrationCustomIconsByApp,
    };
    if (next.isEmpty) {
      updated.remove(key);
    } else {
      updated[key] = List<CustomIconEntry>.unmodifiable(next);
    }
    _integrationCustomIconsByApp = updated;
    notifyListeners();
    await _persistIntegrationCustomIconsByApp();
  }
}
