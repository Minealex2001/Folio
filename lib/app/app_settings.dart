import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';

import 'folio_build_flags.dart';
import 'folio_distribution.dart';
import 'folio_in_app_shortcuts.dart';
import '../services/transcription_hardware_profile.dart';
import '../services/updater/update_release_channel.dart';
import '../services/whisper_service.dart';

enum AiProvider { none, ollama, lmStudio, quillCloud }

/// Ollama y LM Studio solo en escritorio y web; en Android/iOS Quill usa Folio Cloud.
bool get aiLocalProvidersSupported {
  if (kIsWeb) return true;
  return defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS;
}

enum AiEndpointMode { localhostOnly, allowRemote }

enum UiScaleMode { manual, followWindows }

/// Origen del color de acento para Material [ColorScheme.fromSeed].
enum FolioAccentColorMode {
  followSystem,
  folioDefault,
  custom,
}

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

/// Configuración de backup automático por libreta.
class VaultBackupPrefs {
  const VaultBackupPrefs({
    this.enabled = false,
    this.folderEnabled = false,
    this.intervalMinutes =
        AppSettings.defaultScheduledVaultBackupIntervalMinutes,
    this.directory = '',
    this.lastMs = 0,
    this.alsoCloud = false,
  });

  final bool enabled;
  final bool folderEnabled;
  final int intervalMinutes;
  final String directory;
  final int lastMs;
  final bool alsoCloud;

  static const VaultBackupPrefs defaults = VaultBackupPrefs();

  VaultBackupPrefs copyWith({
    bool? enabled,
    bool? folderEnabled,
    int? intervalMinutes,
    String? directory,
    int? lastMs,
    bool? alsoCloud,
  }) {
    return VaultBackupPrefs(
      enabled: enabled ?? this.enabled,
      folderEnabled: folderEnabled ?? this.folderEnabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      directory: directory ?? this.directory,
      lastMs: lastMs ?? this.lastMs,
      alsoCloud: alsoCloud ?? this.alsoCloud,
    );
  }
}

/// Preferencias de la app persistidas (p. ej. tema). No se borran al eliminar la libreta.
class AppSettings extends ChangeNotifier {
  AppSettings({String integrationSecret = ''})
    : _configuredIntegrationSecret = integrationSecret.trim();

  static const _themeModeKey = 'folio_theme_mode';
  static const _uiScaleKey = 'folio_ui_scale';
  static const _uiScaleModeKey = 'folio_ui_scale_mode';
  static const _localeCodeKey = 'folio_locale_code';
  static const _vaultIdleLockMinutesKey = 'folio_vault_idle_lock_minutes';
  static const _vaultLockOnMinimizeKey = 'folio_vault_lock_on_minimize';
  static const _lockScreenAutoQuickUnlockDoneKey =
      'folio_lock_screen_auto_quick_unlock_done_v1';
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
  static const _lastSeenReleaseNotesVersionKey =
      'folio_last_seen_release_notes_version';
  static const _updateReleaseChannelKey = 'folio_update_release_channel';
  static const _betaBannerDismissedKey = 'folio_beta_banner_dismissed';
  static const _inAppShortcutsKey = 'folio_in_app_shortcuts_json';
  static const _approvedIntegrationAppsKey = 'folio_approved_integration_apps';
  static const _jiraOAuthClientIdKey = 'folio_jira_oauth_client_id';
  static const _editorContentWidthKey = 'folio_editor_content_width';
  static const _workspaceSidebarWidthKey = 'folio_workspace_sidebar_width';
  static const _workspaceSidebarCollapsedKey =
      'folio_workspace_sidebar_collapsed';
  static const _workspaceSidebarAutoRevealKey =
      'folio_workspace_sidebar_auto_reveal';
  static const _workspaceSidebarCollapsedPagesPrefix =
      'folio_workspace_sidebar_collapsed_pages_';
  static const _workspacePageOutlineVisibleKey =
      'folio_workspace_page_outline_visible';
  static const _aiChatPanelCollapsedKey = 'folio_ai_chat_panel_collapsed';
  static const _aiChatPanelWidthKey = 'folio_ai_chat_panel_width';
  static const _aiChatPanelHeightKey = 'folio_ai_chat_panel_height';
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
  static const _scheduledVaultBackupIntervalMinutesKey =
      'folio_scheduled_vault_backup_interval_minutes_v2';
  static const _scheduledVaultBackupDirectoryKey =
      'folio_scheduled_vault_backup_directory';
  static const _lastScheduledVaultBackupMsKey =
      'folio_last_scheduled_vault_backup_ms';
  static const _scheduledVaultBackupAlsoUploadCloudKey =
      'folio_scheduled_vault_backup_also_cloud_v1';
  static const _scheduledVaultBackupFolderEnabledKey =
      'folio_scheduled_vault_backup_folder_enabled_v1';
  static const _meetingNoteMicDeviceIdKey = 'folio_meeting_note_mic_device_id';
  static const _meetingNoteSystemDeviceIdKey =
      'folio_meeting_note_system_device_id';
  static const _meetingNoteModelIdKey = 'folio_meeting_note_model_id';
  static const _meetingNoteAutoWhisperModelKey =
      'folio_meeting_note_auto_whisper_model';
  static const _meetingNoteForceLocalTranscriptionKey =
      'folio_meeting_note_force_local_transcription';
  static const _driveDeleteOriginalsOnUploadKey =
      'folio_drive_delete_originals_on_upload';
  static const _telemetryEnabledKey = 'folio_telemetry_enabled';
  static const _autoCrashReportsKey = 'folio_auto_crash_reports';
  static const _accentColorModeKey = 'folio_accent_color_mode';
  static const _customAccentArgbKey = 'folio_custom_accent_argb';
  static const int maxRecentSearchQueries = 10;

  /// Canal de distribución (Store / GitHub / web) vía `--dart-define=FOLIO_DISTRIBUTION=...`.
  static const String distributionChannelFromEnvironment = FolioDistribution.raw;

  /// 30 min, luego cada hora hasta 24 h (índices del slider / menú).
  static const List<int> scheduledVaultBackupIntervalChoicesMinutes = [
    30,
    60,
    120,
    180,
    240,
    300,
    360,
    420,
    480,
    540,
    600,
    660,
    720,
    780,
    840,
    900,
    960,
    1020,
    1080,
    1140,
    1200,
    1260,
    1320,
    1380,
    1440,
  ];

  static const int defaultScheduledVaultBackupIntervalMinutes = 1440;

  static int nearestScheduledBackupIntervalMinutes(int minutes) {
    var best = scheduledVaultBackupIntervalChoicesMinutes.first;
    var bestDist = (minutes - best).abs();
    for (final m in scheduledVaultBackupIntervalChoicesMinutes) {
      final d = (minutes - m).abs();
      if (d < bestDist) {
        best = m;
        bestDist = d;
      }
    }
    return best;
  }

  static const int defaultVaultIdleLockMinutes = 15;
  static const String defaultGlobalSearchHotkey = 'Ctrl+Shift+K';
  static const int defaultAiTimeoutMs = 30000;
  static const String defaultOllamaUrl = 'http://127.0.0.1:11434';
  static const String defaultLmStudioUrl = 'http://127.0.0.1:1234';
  static const String defaultOllamaModel = 'llama3.1:8b';
  static const String defaultLmStudioModel = 'local-model';
  static const int defaultAiContextWindowTokens = 131072;
  static const double minUiScale = 0.85;
  static const double maxUiScale = 1.60;
  static const double defaultUiScale = 1.0;
  static const double minEditorContentWidth = 840;
  static const double maxEditorContentWidth = 1400;
  static const double defaultEditorContentWidth = 1080;
  static const double minWorkspaceSidebarWidth = 220;
  static const double maxWorkspaceSidebarWidth = 480;
  static const double defaultWorkspaceSidebarWidth = 320;
  static const double minAiChatPanelWidth = 280;
  static const double maxAiChatPanelWidth = 720;
  static const double defaultAiChatPanelWidth = 360;
  static const double minAiChatPanelHeight = 320;
  static const double maxAiChatPanelHeight = 1000;
  static const double defaultAiChatPanelHeight = 520;
  static const String defaultUpdaterGithubOwner = 'Minealex2001';
  static const String defaultUpdaterGithubRepo = 'Folio';
  static const bool defaultCheckUpdatesOnStartup = true;
  static const UpdateReleaseChannel defaultUpdateReleaseChannel =
      UpdateReleaseChannel.stable;

  /// Portal Folio (vinculación cuenta web). Puede sustituirse con [folioWebPortalBaseUrlFromEnvironment].
  static const String defaultFolioWebPortalBaseUrl = 'http://localhost:3001/';

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
  double _uiScale = defaultUiScale;
  UiScaleMode _uiScaleMode = UiScaleMode.manual;
  Locale? _locale;
  int _vaultIdleLockMinutes = defaultVaultIdleLockMinutes;
  bool _vaultLockOnMinimize = false;
  bool _lockScreenAutoQuickUnlockDone = false;
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
  String _lastSeenReleaseNotesVersion = '';
  UpdateReleaseChannel _updateReleaseChannel = defaultUpdateReleaseChannel;
  bool _betaBannerDismissed = false;
  double _editorContentWidth = defaultEditorContentWidth;
  double _workspaceSidebarWidth = defaultWorkspaceSidebarWidth;
  bool _workspaceSidebarCollapsed = false;
  bool _workspaceSidebarAutoReveal = false;
  bool _workspacePageOutlineVisible = true;
  bool _aiChatPanelCollapsed = false;
  double _aiChatPanelWidth = defaultAiChatPanelWidth;
  double _aiChatPanelHeight = defaultAiChatPanelHeight;
  Map<FolioInAppShortcut, SingleActivator> _inAppShortcuts =
      defaultShortcutMap();
  final String _configuredIntegrationSecret;
  String _integrationSecret = '';
  String _jiraOAuthClientId = '';
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
  int _scheduledVaultBackupIntervalMinutes =
      defaultScheduledVaultBackupIntervalMinutes;
  String _scheduledVaultBackupDirectory = '';
  int _lastScheduledVaultBackupMs = 0;
  bool _scheduledVaultBackupAlsoUploadCloud = false;
  bool _scheduledVaultBackupFolderEnabled = false;
  String _meetingNoteMicDeviceId = '';
  String _meetingNoteSystemDeviceId = '';
  String _meetingNoteModelId = 'base';
  bool _meetingNoteAutoWhisperModel = false;
  bool _meetingNoteForceLocalTranscription = false;
  bool _driveDeleteOriginalsOnUpload = false;
  bool _telemetryEnabled = false;
  bool _autoCrashReports = false;
  FolioAccentColorMode _accentColorMode = FolioAccentColorMode.followSystem;
  int _customAccentArgb = 0xFF455A64;

  ThemeMode get themeMode => _themeMode;

  /// Semilla de color para temas claro/oscuro (Material 3).
  Color resolveAccentSeedColor() {
    switch (_accentColorMode) {
      case FolioAccentColorMode.followSystem:
        return SystemTheme.accentColor.accent;
      case FolioAccentColorMode.folioDefault:
        return const Color(0xFF455A64);
      case FolioAccentColorMode.custom:
        return Color(_customAccentArgb);
    }
  }

  bool get telemetryEnabled => _telemetryEnabled;
  bool get autoCrashReports => _autoCrashReports;
  FolioAccentColorMode get accentColorMode => _accentColorMode;
  int get customAccentArgb => _customAccentArgb;

  double get uiScale => _uiScale;
  UiScaleMode get uiScaleMode => _uiScaleMode;
  Locale? get locale => _locale;
  int get vaultIdleLockMinutes => _vaultIdleLockMinutes;
  bool get vaultLockOnMinimize => _vaultLockOnMinimize;
  bool get lockScreenAutoQuickUnlockDone => _lockScreenAutoQuickUnlockDone;
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
  String get lastSeenReleaseNotesVersion => _lastSeenReleaseNotesVersion;
  String get updaterGithubOwner => defaultUpdaterGithubOwner;
  String get updaterGithubRepo => defaultUpdaterGithubRepo;
  bool get checkUpdatesOnStartup => defaultCheckUpdatesOnStartup;
  UpdateReleaseChannel get updateReleaseChannel => _updateReleaseChannel;
  double get editorContentWidth => _editorContentWidth;
  double get workspaceSidebarWidth => _workspaceSidebarWidth;
  bool get workspaceSidebarCollapsed => _workspaceSidebarCollapsed;
  bool get workspaceSidebarAutoReveal => _workspaceSidebarAutoReveal;
  bool get workspacePageOutlineVisible => _workspacePageOutlineVisible;
  bool get aiChatPanelCollapsed => _aiChatPanelCollapsed;
  double get aiChatPanelWidth => _aiChatPanelWidth;
  double get aiChatPanelHeight => _aiChatPanelHeight;
  String get integrationSecret => _integrationSecret;

  /// Temporal: `client_id` para OAuth 3LO de Jira Cloud configurado por usuario.
  /// En producción se espera que esto venga del entorno/build, pero este override
  /// permite iterar sin recompilar.
  String get jiraOAuthClientId => _jiraOAuthClientId;

  Future<void> setJiraOAuthClientId(String value) async {
    final next = value.trim();
    if (next == _jiraOAuthClientId) return;
    _jiraOAuthClientId = next;
    final p = await SharedPreferences.getInstance();
    if (next.isEmpty) {
      await p.remove(_jiraOAuthClientIdKey);
    } else {
      await p.setString(_jiraOAuthClientIdKey, next);
    }
    notifyListeners();
  }

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
  int get scheduledVaultBackupIntervalMinutes =>
      _scheduledVaultBackupIntervalMinutes;

  int get scheduledVaultBackupIntervalChoiceIndex {
    final choices = scheduledVaultBackupIntervalChoicesMinutes;
    final i = choices.indexOf(_scheduledVaultBackupIntervalMinutes);
    if (i >= 0) return i;
    return choices.indexOf(
      nearestScheduledBackupIntervalMinutes(
        _scheduledVaultBackupIntervalMinutes,
      ),
    );
  }

  String get scheduledVaultBackupDirectory => _scheduledVaultBackupDirectory;
  int get lastScheduledVaultBackupMs => _lastScheduledVaultBackupMs;
  bool get scheduledVaultBackupAlsoUploadCloud =>
      _scheduledVaultBackupAlsoUploadCloud;
  bool get scheduledVaultBackupFolderEnabled =>
      _scheduledVaultBackupFolderEnabled;
  String get meetingNoteMicDeviceId => _meetingNoteMicDeviceId;
  String get meetingNoteSystemDeviceId => _meetingNoteSystemDeviceId;
  String get meetingNoteModelId => _meetingNoteModelId;

  bool get meetingNoteAutoWhisperModel => _meetingNoteAutoWhisperModel;

  bool get meetingNoteForceLocalTranscription =>
      _meetingNoteForceLocalTranscription;

  bool get driveDeleteOriginalsOnUpload => _driveDeleteOriginalsOnUpload;

  /// Modelo Whisper efectivo (manual o recomendado por hardware si [meetingNoteAutoWhisperModel]).
  String resolvedMeetingNoteWhisperModelId() {
    final snap = TranscriptionHardwareProfile.loadCached();
    final chosen = _meetingNoteAutoWhisperModel
        ? snap.recommendedWhisperModelId
        : (_meetingNoteModelId.trim().isEmpty ? 'base' : _meetingNoteModelId);
    return WhisperService.instance.modelById(chosen)?.id ?? 'base';
  }

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
    _uiScale = _sanitizeUiScale(p.getDouble(_uiScaleKey));
    _uiScaleMode = _parseUiScaleMode(p.getString(_uiScaleModeKey));
    final localeCode = p.getString(_localeCodeKey);
    _locale = localeCode == null || localeCode.isEmpty
        ? null
        : Locale(localeCode);
    final idleMinutes = p.getInt(_vaultIdleLockMinutesKey);
    _vaultIdleLockMinutes = (idleMinutes == null || idleMinutes <= 0)
        ? defaultVaultIdleLockMinutes
        : idleMinutes;
    _vaultLockOnMinimize = p.getBool(_vaultLockOnMinimizeKey) ?? false;
    _lockScreenAutoQuickUnlockDone =
        p.getBool(_lockScreenAutoQuickUnlockDoneKey) ?? false;
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
      _aiModel =
          p.getString(_aiModelKey) ?? defaultModelForProvider(_aiProvider);
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
    _lastSeenReleaseNotesVersion =
        (p.getString(_lastSeenReleaseNotesVersionKey) ?? '').trim();
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
    _aiChatPanelCollapsed = p.getBool(_aiChatPanelCollapsedKey) ?? false;
    _aiChatPanelWidth = _sanitizeAiChatPanelWidth(
      p.getDouble(_aiChatPanelWidthKey),
    );
    _aiChatPanelHeight = _sanitizeAiChatPanelHeight(
      p.getDouble(_aiChatPanelHeightKey),
    );
    _inAppShortcuts = parseShortcutOverrides(
      p.getString(_inAppShortcutsKey),
      defaultShortcutMap(),
    );
    _jiraOAuthClientId = (p.getString(_jiraOAuthClientIdKey) ?? '').trim();
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
    final storedMinutes = p.getInt(_scheduledVaultBackupIntervalMinutesKey);
    final legacyHours = p.getInt(_scheduledVaultBackupIntervalHoursKey);
    if (storedMinutes != null) {
      _scheduledVaultBackupIntervalMinutes =
          _sanitizeScheduledVaultBackupIntervalMinutes(storedMinutes);
    } else if (legacyHours != null) {
      final migratedMin = (legacyHours * 60).clamp(
        scheduledVaultBackupIntervalChoicesMinutes.first,
        scheduledVaultBackupIntervalChoicesMinutes.last,
      );
      _scheduledVaultBackupIntervalMinutes =
          nearestScheduledBackupIntervalMinutes(migratedMin);
      await p.setInt(
        _scheduledVaultBackupIntervalMinutesKey,
        _scheduledVaultBackupIntervalMinutes,
      );
      await p.remove(_scheduledVaultBackupIntervalHoursKey);
    } else {
      _scheduledVaultBackupIntervalMinutes =
          defaultScheduledVaultBackupIntervalMinutes;
    }
    _scheduledVaultBackupDirectory =
        (p.getString(_scheduledVaultBackupDirectoryKey) ?? '').trim();
    _lastScheduledVaultBackupMs = p.getInt(_lastScheduledVaultBackupMsKey) ?? 0;
    _scheduledVaultBackupAlsoUploadCloud =
        p.getBool(_scheduledVaultBackupAlsoUploadCloudKey) ?? false;
    // Migración: si la clave no existe, inferir del directorio configurado.
    _scheduledVaultBackupFolderEnabled =
        p.getBool(_scheduledVaultBackupFolderEnabledKey) ??
        _scheduledVaultBackupDirectory.isNotEmpty;
    _meetingNoteMicDeviceId = (p.getString(_meetingNoteMicDeviceIdKey) ?? '')
        .trim();
    _meetingNoteSystemDeviceId =
        (p.getString(_meetingNoteSystemDeviceIdKey) ?? '').trim();
    _meetingNoteModelId = (p.getString(_meetingNoteModelIdKey) ?? 'base')
        .trim();
    if (_meetingNoteModelId.isEmpty) {
      _meetingNoteModelId = 'base';
    }
    _meetingNoteAutoWhisperModel =
        p.getBool(_meetingNoteAutoWhisperModelKey) ?? false;
    _meetingNoteForceLocalTranscription =
        p.getBool(_meetingNoteForceLocalTranscriptionKey) ?? false;
    _driveDeleteOriginalsOnUpload =
        p.getBool(_driveDeleteOriginalsOnUploadKey) ?? false;
    _telemetryEnabled = p.getBool(_telemetryEnabledKey) ?? false;
    _autoCrashReports = p.getBool(_autoCrashReportsKey) ?? false;
    _accentColorMode =
        _parseAccentColorMode(p.getString(_accentColorModeKey)) ??
        FolioAccentColorMode.followSystem;
    final storedAccent = p.getInt(_customAccentArgbKey);
    _customAccentArgb =
        storedAccent != null && storedAccent != 0
        ? storedAccent
        : 0xFF455A64;
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
        AiProvider.quillCloud: List<String>.from(
          p.getStringList(_aiModelsKeyForProvider(AiProvider.quillCloud)) ??
              const <String>['quill-cloud'],
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

  FolioAccentColorMode? _parseAccentColorMode(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'followSystem':
        return FolioAccentColorMode.followSystem;
      case 'folioDefault':
        return FolioAccentColorMode.folioDefault;
      case 'custom':
        return FolioAccentColorMode.custom;
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
      case 'quillCloud':
        return AiProvider.quillCloud;
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

  UiScaleMode _parseUiScaleMode(String? raw) {
    switch (raw) {
      case 'followWindows':
        return UiScaleMode.followWindows;
      default:
        return UiScaleMode.manual;
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

  int _sanitizeScheduledVaultBackupIntervalMinutes(int? value) {
    final raw = value ?? defaultScheduledVaultBackupIntervalMinutes;
    if (scheduledVaultBackupIntervalChoicesMinutes.contains(raw)) return raw;
    return nearestScheduledBackupIntervalMinutes(raw);
  }

  double _sanitizeUiScale(double? value) {
    final raw = value ?? defaultUiScale;
    if (raw < minUiScale) return minUiScale;
    if (raw > maxUiScale) return maxUiScale;
    return raw;
  }

  double resolveEffectiveUiScale({
    required bool isWindows,
    required double devicePixelRatio,
  }) {
    if (_uiScaleMode == UiScaleMode.followWindows && isWindows) {
      return _sanitizeUiScale(devicePixelRatio);
    }
    return _uiScale;
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

  double _sanitizeAiChatPanelWidth(double? value) {
    final raw = value ?? defaultAiChatPanelWidth;
    if (raw < minAiChatPanelWidth) return minAiChatPanelWidth;
    if (raw > maxAiChatPanelWidth) return maxAiChatPanelWidth;
    return raw;
  }

  double _sanitizeAiChatPanelHeight(double? value) {
    final raw = value ?? defaultAiChatPanelHeight;
    if (raw < minAiChatPanelHeight) return minAiChatPanelHeight;
    if (raw > maxAiChatPanelHeight) return maxAiChatPanelHeight;
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
      case AiProvider.quillCloud:
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
      case AiProvider.quillCloud:
        return 'quill-cloud';
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

  Future<void> setUiScale(double value) async {
    final safe = _sanitizeUiScale(value);
    if ((_uiScale - safe).abs() < 0.01) return;
    _uiScale = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_uiScaleKey, safe);
  }

  Future<void> setUiScaleMode(UiScaleMode value) async {
    if (_uiScaleMode == value) return;
    _uiScaleMode = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_uiScaleModeKey, value.name);
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
    if (value == AiProvider.quillCloud) {
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

  /// Tras el primer intento automático de Hello/passkey en la pantalla de bloqueo.
  Future<void> setLockScreenAutoQuickUnlockDone() async {
    if (_lockScreenAutoQuickUnlockDone) return;
    _lockScreenAutoQuickUnlockDone = true;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_lockScreenAutoQuickUnlockDoneKey, true);
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

  Future<void> setLastSeenReleaseNotesVersion(String value) async {
    final safe = value.trim();
    if (_lastSeenReleaseNotesVersion == safe) return;
    _lastSeenReleaseNotesVersion = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    if (safe.isEmpty) {
      await p.remove(_lastSeenReleaseNotesVersionKey);
    } else {
      await p.setString(_lastSeenReleaseNotesVersionKey, safe);
    }
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

  String _workspaceSidebarCollapsedPagesKey(String? vaultId) {
    final safeVault = (vaultId == null || vaultId.trim().isEmpty)
        ? 'default'
        : vaultId.trim();
    return '$_workspaceSidebarCollapsedPagesPrefix$safeVault';
  }

  Future<Set<String>> loadWorkspaceSidebarCollapsedPageIds({
    required String? vaultId,
    required Set<String> validPageIds,
  }) async {
    final p = await SharedPreferences.getInstance();
    final saved =
        p.getStringList(_workspaceSidebarCollapsedPagesKey(vaultId)) ??
        const <String>[];
    return saved.where(validPageIds.contains).toSet();
  }

  Future<void> persistWorkspaceSidebarCollapsedPageIds({
    required String? vaultId,
    required Set<String> collapsedPageIds,
  }) async {
    final p = await SharedPreferences.getInstance();
    final sorted = collapsedPageIds.toList()..sort();
    await p.setStringList(_workspaceSidebarCollapsedPagesKey(vaultId), sorted);
  }

  Future<void> setWorkspaceSidebarCollapsed(bool value) async {
    if (_workspaceSidebarCollapsed == value) return;
    _workspaceSidebarCollapsed = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_workspaceSidebarCollapsedKey, value);
  }

  Future<void> setAiChatPanelCollapsed(bool value) async {
    if (_aiChatPanelCollapsed == value) return;
    _aiChatPanelCollapsed = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_aiChatPanelCollapsedKey, value);
  }

  Future<void> setAiChatPanelWidth(double value) async {
    final safe = _sanitizeAiChatPanelWidth(value);
    if ((_aiChatPanelWidth - safe).abs() < 0.5) return;
    _aiChatPanelWidth = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_aiChatPanelWidthKey, safe);
  }

  Future<void> setAiChatPanelHeight(double value) async {
    final safe = _sanitizeAiChatPanelHeight(value);
    if ((_aiChatPanelHeight - safe).abs() < 0.5) return;
    _aiChatPanelHeight = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_aiChatPanelHeightKey, safe);
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
      await p.setInt(
        _lastScheduledVaultBackupMsKey,
        _lastScheduledVaultBackupMs,
      );
    }
  }

  Future<void> setScheduledVaultBackupIntervalMinutes(int value) async {
    final safe = _sanitizeScheduledVaultBackupIntervalMinutes(value);
    if (_scheduledVaultBackupIntervalMinutes == safe) return;
    _scheduledVaultBackupIntervalMinutes = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_scheduledVaultBackupIntervalMinutesKey, safe);
    if (p.containsKey(_scheduledVaultBackupIntervalHoursKey)) {
      await p.remove(_scheduledVaultBackupIntervalHoursKey);
    }
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

  Future<void> setScheduledVaultBackupFolderEnabled(bool value) async {
    if (_scheduledVaultBackupFolderEnabled == value) return;
    _scheduledVaultBackupFolderEnabled = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_scheduledVaultBackupFolderEnabledKey, value);
  }

  Future<void> setMeetingNoteMicDeviceId(String value) async {
    final safe = value.trim();
    if (_meetingNoteMicDeviceId == safe) return;
    _meetingNoteMicDeviceId = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    if (safe.isEmpty) {
      await p.remove(_meetingNoteMicDeviceIdKey);
    } else {
      await p.setString(_meetingNoteMicDeviceIdKey, safe);
    }
  }

  Future<void> setMeetingNoteSystemDeviceId(String value) async {
    final safe = value.trim();
    if (_meetingNoteSystemDeviceId == safe) return;
    _meetingNoteSystemDeviceId = safe;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    if (safe.isEmpty) {
      await p.remove(_meetingNoteSystemDeviceIdKey);
    } else {
      await p.setString(_meetingNoteSystemDeviceIdKey, safe);
    }
  }

  Future<void> setMeetingNoteModelId(String value) async {
    final safe = value.trim().isEmpty ? 'base' : value.trim();
    if (_meetingNoteModelId == safe && !_meetingNoteAutoWhisperModel) return;
    _meetingNoteModelId = safe;
    if (_meetingNoteAutoWhisperModel) {
      _meetingNoteAutoWhisperModel = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_meetingNoteAutoWhisperModelKey, false);
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_meetingNoteModelIdKey, safe);
  }

  Future<void> setMeetingNoteAutoWhisperModel(bool value) async {
    if (_meetingNoteAutoWhisperModel == value) return;
    _meetingNoteAutoWhisperModel = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_meetingNoteAutoWhisperModelKey, value);
  }

  Future<void> setMeetingNoteForceLocalTranscription(bool value) async {
    if (_meetingNoteForceLocalTranscription == value) return;
    _meetingNoteForceLocalTranscription = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_meetingNoteForceLocalTranscriptionKey, value);
  }

  Future<void> setDriveDeleteOriginalsOnUpload(bool value) async {
    if (_driveDeleteOriginalsOnUpload == value) return;
    _driveDeleteOriginalsOnUpload = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_driveDeleteOriginalsOnUploadKey, value);
  }

  Future<void> setTelemetryEnabled(bool value) async {
    if (_telemetryEnabled == value) return;
    _telemetryEnabled = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_telemetryEnabledKey, value);
  }

  Future<void> setAutoCrashReports(bool value) async {
    if (_autoCrashReports == value) return;
    _autoCrashReports = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_autoCrashReportsKey, value);
  }

  Future<void> setAccentColorMode(FolioAccentColorMode mode) async {
    if (_accentColorMode == mode) return;
    _accentColorMode = mode;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    final v = switch (mode) {
      FolioAccentColorMode.followSystem => 'followSystem',
      FolioAccentColorMode.folioDefault => 'folioDefault',
      FolioAccentColorMode.custom => 'custom',
    };
    await p.setString(_accentColorModeKey, v);
  }

  Future<void> setCustomAccentArgb(int argb) async {
    if (_customAccentArgb == argb) return;
    _customAccentArgb = argb;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_customAccentArgbKey, argb);
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
    if (key.isEmpty || current == null) {
      return;
    }
    if (!current.matches(integrationVersion: integrationVersion)) {
      return;
    }
    final safeName = appName.trim().isEmpty ? key : appName.trim();
    final safeVersion = appVersion.trim();
    if (current.appName == safeName && current.appVersion == safeVersion) {
      return;
    }
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

  // ─── Backup programado por libreta ──────────────────────────────────────────

  static String _vbEnabledKey(String vid) =>
      'folio_vault_backup_enabled_v2_$vid';
  static String _vbFolderEnabledKey(String vid) =>
      'folio_vault_backup_folder_enabled_v2_$vid';
  static String _vbIntervalMinutesKey(String vid) =>
      'folio_vault_backup_interval_v2_$vid';
  static String _vbDirectoryKey(String vid) => 'folio_vault_backup_dir_v2_$vid';
  static String _vbLastMsKey(String vid) =>
      'folio_vault_backup_last_ms_v2_$vid';
  static String _vbAlsoCloudKey(String vid) =>
      'folio_vault_backup_cloud_v2_$vid';

  /// Devuelve la configuración de backup automático para la libreta [vaultId].
  /// Si no existe configuración per-libreta pero hay ajustes globales legacy,
  /// migra automáticamente y borra las claves globales.
  Future<VaultBackupPrefs> getVaultBackupPrefs(String? vaultId) async {
    final vid = (vaultId ?? '').trim();
    if (vid.isEmpty) return VaultBackupPrefs.defaults;
    final p = await SharedPreferences.getInstance();
    // Si ya hay configuración per-libreta, devolverla directamente.
    if (p.containsKey(_vbEnabledKey(vid))) {
      return VaultBackupPrefs(
        enabled: p.getBool(_vbEnabledKey(vid)) ?? false,
        folderEnabled: p.getBool(_vbFolderEnabledKey(vid)) ?? false,
        intervalMinutes: _sanitizeScheduledVaultBackupIntervalMinutes(
          p.getInt(_vbIntervalMinutesKey(vid)) ??
              defaultScheduledVaultBackupIntervalMinutes,
        ),
        directory: (p.getString(_vbDirectoryKey(vid)) ?? '').trim(),
        lastMs: p.getInt(_vbLastMsKey(vid)) ?? 0,
        alsoCloud: p.getBool(_vbAlsoCloudKey(vid)) ?? false,
      );
    }
    // Migración: si había configuración global legacy, moverla a esta libreta.
    final globalEnabled = p.getBool(_scheduledVaultBackupEnabledKey) ?? false;
    final globalDir = (p.getString(_scheduledVaultBackupDirectoryKey) ?? '')
        .trim();
    if (globalEnabled || globalDir.isNotEmpty) {
      final storedMinutes = p.getInt(_scheduledVaultBackupIntervalMinutesKey);
      final legacyHours = p.getInt(_scheduledVaultBackupIntervalHoursKey);
      int intervalMin = defaultScheduledVaultBackupIntervalMinutes;
      if (storedMinutes != null) {
        intervalMin = _sanitizeScheduledVaultBackupIntervalMinutes(
          storedMinutes,
        );
      } else if (legacyHours != null) {
        intervalMin = nearestScheduledBackupIntervalMinutes(
          (legacyHours * 60).clamp(
            scheduledVaultBackupIntervalChoicesMinutes.first,
            scheduledVaultBackupIntervalChoicesMinutes.last,
          ),
        );
      }
      final migrated = VaultBackupPrefs(
        enabled: globalEnabled,
        folderEnabled:
            p.getBool(_scheduledVaultBackupFolderEnabledKey) ??
            globalDir.isNotEmpty,
        intervalMinutes: intervalMin,
        directory: globalDir,
        lastMs: p.getInt(_lastScheduledVaultBackupMsKey) ?? 0,
        alsoCloud: p.getBool(_scheduledVaultBackupAlsoUploadCloudKey) ?? false,
      );
      // Escribir en per-libreta y borrar claves globales.
      await _writeVaultBackupPrefs(p, vid, migrated);
      for (final k in [
        _scheduledVaultBackupEnabledKey,
        _scheduledVaultBackupFolderEnabledKey,
        _scheduledVaultBackupIntervalMinutesKey,
        _scheduledVaultBackupIntervalHoursKey,
        _scheduledVaultBackupDirectoryKey,
        _lastScheduledVaultBackupMsKey,
        _scheduledVaultBackupAlsoUploadCloudKey,
      ]) {
        await p.remove(k);
      }
      notifyListeners();
      return migrated;
    }
    return VaultBackupPrefs.defaults;
  }

  Future<void> _writeVaultBackupPrefs(
    SharedPreferences p,
    String vid,
    VaultBackupPrefs prefs,
  ) async {
    await p.setBool(_vbEnabledKey(vid), prefs.enabled);
    await p.setBool(_vbFolderEnabledKey(vid), prefs.folderEnabled);
    await p.setInt(_vbIntervalMinutesKey(vid), prefs.intervalMinutes);
    if (prefs.directory.isEmpty) {
      await p.remove(_vbDirectoryKey(vid));
    } else {
      await p.setString(_vbDirectoryKey(vid), prefs.directory);
    }
    await p.setInt(_vbLastMsKey(vid), prefs.lastMs < 0 ? 0 : prefs.lastMs);
    await p.setBool(_vbAlsoCloudKey(vid), prefs.alsoCloud);
  }

  Future<void> setVaultBackupEnabled(String? vaultId, bool value) async {
    final vid = (vaultId ?? '').trim();
    if (vid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_vbEnabledKey(vid), value);
    if (value && !(p.containsKey(_vbLastMsKey(vid)))) {
      await p.setInt(_vbLastMsKey(vid), DateTime.now().millisecondsSinceEpoch);
    }
    notifyListeners();
  }

  Future<void> setVaultBackupFolderEnabled(String? vaultId, bool value) async {
    final vid = (vaultId ?? '').trim();
    if (vid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_vbFolderEnabledKey(vid), value);
    notifyListeners();
  }

  Future<void> setVaultBackupIntervalMinutes(String? vaultId, int value) async {
    final vid = (vaultId ?? '').trim();
    if (vid.isEmpty) return;
    final safe = _sanitizeScheduledVaultBackupIntervalMinutes(value);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_vbIntervalMinutesKey(vid), safe);
    notifyListeners();
  }

  Future<void> setVaultBackupDirectory(String? vaultId, String path) async {
    final vid = (vaultId ?? '').trim();
    if (vid.isEmpty) return;
    final safe = path.trim();
    final p = await SharedPreferences.getInstance();
    if (safe.isEmpty) {
      await p.remove(_vbDirectoryKey(vid));
    } else {
      await p.setString(_vbDirectoryKey(vid), safe);
    }
    notifyListeners();
  }

  Future<void> setVaultBackupLastMs(String? vaultId, int value) async {
    final vid = (vaultId ?? '').trim();
    if (vid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_vbLastMsKey(vid), value < 0 ? 0 : value);
    notifyListeners();
  }

  Future<void> setVaultBackupAlsoCloud(String? vaultId, bool value) async {
    final vid = (vaultId ?? '').trim();
    if (vid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_vbAlsoCloudKey(vid), value);
    notifyListeners();
  }

  static int vaultBackupIntervalChoiceIndex(int intervalMinutes) {
    final choices = scheduledVaultBackupIntervalChoicesMinutes;
    final i = choices.indexOf(intervalMinutes);
    if (i >= 0) return i;
    return choices.indexOf(
      nearestScheduledBackupIntervalMinutes(intervalMinutes),
    );
  }

  // ─── Task capture ────────────────────────────────────────────────────────────

  static String _taskInboxPagePrefsKey(String vaultId) =>
      'folio_task_inbox_page_v1_${vaultId.trim()}';

  static String _taskAliasesPrefsKey(String vaultId) =>
      'folio_task_aliases_v1_${vaultId.trim()}';

  /// Página donde se añaden las tareas de captura rápida para esta libreta.
  Future<String?> getTaskInboxPageId(String? vaultId) async {
    final id = (vaultId ?? '').trim();
    if (id.isEmpty) return null;
    final p = await SharedPreferences.getInstance();
    final v = (p.getString(_taskInboxPagePrefsKey(id)) ?? '').trim();
    return v.isEmpty ? null : v;
  }

  Future<void> setTaskInboxPageId(String? vaultId, String? pageId) async {
    final id = (vaultId ?? '').trim();
    if (id.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final pid = pageId?.trim() ?? '';
    if (pid.isEmpty) {
      await p.remove(_taskInboxPagePrefsKey(id));
    } else {
      await p.setString(_taskInboxPagePrefsKey(id), pid);
    }
  }

  /// Mapeo etiqueta (sin `#`, minúsculas) o `#tag` → id de página destino.
  Future<Map<String, String>> getTaskAliasPageMap(String? vaultId) async {
    final id = (vaultId ?? '').trim();
    if (id.isEmpty) return const {};
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_taskAliasesPrefsKey(id));
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final out = <String, String>{};
      for (final e in decoded.entries) {
        final k = e.key.toString().trim().toLowerCase();
        final v = e.value.toString().trim();
        if (k.isNotEmpty && v.isNotEmpty) {
          out[k] = v;
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  Future<void> setTaskAliasPageMap(
    String? vaultId,
    Map<String, String> map,
  ) async {
    final id = (vaultId ?? '').trim();
    if (id.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final clean = <String, String>{};
    for (final e in map.entries) {
      final k = e.key.trim().toLowerCase();
      final v = e.value.trim();
      if (k.isNotEmpty && v.isNotEmpty) {
        clean[k] = v;
      }
    }
    if (clean.isEmpty) {
      await p.remove(_taskAliasesPrefsKey(id));
    } else {
      await p.setString(_taskAliasesPrefsKey(id), jsonEncode(clean));
    }
  }
}
