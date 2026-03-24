import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de la app persistidas (p. ej. tema). No se borran al eliminar el cofre.
class AppSettings extends ChangeNotifier {
  AppSettings();

  static const _themeModeKey = 'folio_theme_mode';
  static const _localeCodeKey = 'folio_locale_code';

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_themeModeKey);
    _themeMode = _parseThemeMode(raw) ?? ThemeMode.system;
    final localeCode = p.getString(_localeCodeKey);
    _locale = localeCode == null || localeCode.isEmpty
        ? null
        : Locale(localeCode);
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
}
