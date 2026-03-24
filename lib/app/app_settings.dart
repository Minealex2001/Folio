import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/updater/update_release_channel.dart';

enum AiProvider { none, ollama, lmStudio }

enum AiEndpointMode { localhostOnly, allowRemote }

/// Preferencias de la app persistidas (p. ej. tema). No se borran al eliminar el cofre.
class AppSettings extends ChangeNotifier {
  AppSettings();

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
  static const _aiLaunchProviderWithAppKey = 'folio_ai_launch_provider_with_app';
  static const _aiContextWindowTokensKey = 'folio_ai_context_window_tokens';
  static const _aiModelsPrefix = 'folio_ai_models_';
  static const _updateReleaseChannelKey = 'folio_update_release_channel';
  static const int defaultVaultIdleLockMinutes = 15;
  static const String defaultGlobalSearchHotkey = 'Ctrl+Shift+K';
  static const int defaultAiTimeoutMs = 30000;
  static const String defaultOllamaUrl = 'http://127.0.0.1:11434';
  static const String defaultLmStudioUrl = 'http://127.0.0.1:1234';
  static const String defaultOllamaModel = 'llama3.1:8b';
  static const String defaultLmStudioModel = 'local-model';
  static const int defaultAiContextWindowTokens = 131072;
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
  UpdateReleaseChannel _updateReleaseChannel = defaultUpdateReleaseChannel;

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
  String get updaterGithubOwner => defaultUpdaterGithubOwner;
  String get updaterGithubRepo => defaultUpdaterGithubRepo;
  bool get checkUpdatesOnStartup => defaultCheckUpdatesOnStartup;
  UpdateReleaseChannel get updateReleaseChannel => _updateReleaseChannel;

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
    _aiLaunchProviderWithApp =
        p.getBool(_aiLaunchProviderWithAppKey) ?? false;
    _aiContextWindowTokens = _sanitizeContextWindowTokens(
      p.getInt(_aiContextWindowTokensKey),
    );
    _updateReleaseChannel = _parseUpdateReleaseChannel(
      p.getString(_updateReleaseChannelKey),
    );
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

  Future<void> setUpdateReleaseChannel(UpdateReleaseChannel value) async {
    if (_updateReleaseChannel == value) return;
    _updateReleaseChannel = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_updateReleaseChannelKey, value.name);
  }
}
