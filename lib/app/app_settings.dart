import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'folio_build_flags.dart';
import 'folio_in_app_shortcuts.dart';
import '../services/updater/update_release_channel.dart';

enum AiProvider { none, ollama, lmStudio }

enum AiEndpointMode { localhostOnly, allowRemote }

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

/// Preferencias de la app persistidas (p. ej. tema). No se borran al eliminar el cofre.
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
  static const String defaultUpdaterGithubOwner = 'aleja';
  static const String defaultUpdaterGithubRepo = 'Folio';
  static const bool defaultCheckUpdatesOnStartup = true;
  static const UpdateReleaseChannel defaultUpdateReleaseChannel =
      UpdateReleaseChannel.stable;

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
  Map<FolioInAppShortcut, SingleActivator> _inAppShortcuts =
      defaultShortcutMap();
  final String _configuredIntegrationSecret;
  String _integrationSecret = '';
  Map<String, IntegrationAppApproval> _approvedIntegrationApps = {};

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
  bool get isAiAvailable => true;
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
  String get integrationSecret => _integrationSecret;
  List<IntegrationAppApproval> get approvedIntegrationAppApprovals =>
      _approvedIntegrationApps.values.toList(growable: false);
  Map<String, String> get approvedIntegrationApps {
    final mapped = <String, String>{};
    for (final entry in _approvedIntegrationApps.entries) {
      mapped[entry.key] = entry.value.appName;
    }
    return Map<String, String>.unmodifiable(mapped);
  }

  /// Aviso BETA en la UI (no forma parte del cofre). Controlado por [kFolioShowBetaBanner].
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
    _aiBaseUrl =
        p.getString(_aiBaseUrlKey) ?? defaultUrlForProvider(_aiProvider);
    _aiModel = p.getString(_aiModelKey) ?? defaultModelForProvider(_aiProvider);
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
    _inAppShortcuts = parseShortcutOverrides(
      p.getString(_inAppShortcutsKey),
      defaultShortcutMap(),
    );
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

  double _sanitizeEditorContentWidth(double? value) {
    final raw = value ?? defaultEditorContentWidth;
    if (raw < minEditorContentWidth) return minEditorContentWidth;
    if (raw > maxEditorContentWidth) return maxEditorContentWidth;
    return raw;
  }

  String defaultUrlForProvider(AiProvider provider) {
    switch (provider) {
      case AiProvider.ollama:
        return defaultOllamaUrl;
      case AiProvider.lmStudio:
        return defaultLmStudioUrl;
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
    if (_aiProvider == value) return;
    _aiProvider = value;
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
}
