import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config_store.dart';
import '../config/models/theme_config.dart';
import '../config/models/theme_motion_tokens.dart';
import '../config/models/theme_shape_tokens.dart';
import '../config/models/theme_spacing_tokens.dart';
import 'theme_config_defaults.dart';

/// Dueño en memoria del [ThemeConfig] activo — mismo patrón que
/// `LayoutEngineController`/`DashboardGridController`: mutaciones
/// inmediatas en memoria + persistencia debounced a [ConfigStore].
///
/// `accentMode`/`light`/`dark` siguen viniendo de `AppSettings` (el picker
/// de acento/tema existente no se duplica aquí — ver
/// `AppSettings.onThemeAccentChanged` y
/// `ConfigBootstrap.themeConfigFromAppSettings`). Los campos que edita el
/// editor de temas nuevo (`shape`/`spacing`/`motion`/`surfaceOpacity`) no
/// tienen equivalente en `AppSettings` — viven solo aquí.
class ThemeConfigController extends ChangeNotifier {
  ThemeConfigController(
    this._store, {
    required ThemeConfig initialConfig,
    Duration persistDebounce = const Duration(milliseconds: 400),
  }) : _config = initialConfig,
       _persistDebounce = persistDebounce;

  final ConfigStore _store;
  final Duration _persistDebounce;
  ThemeConfig _config;
  Timer? _persistTimer;

  static Future<ThemeConfigController> load(
    ConfigStore store, {
    required String id,
  }) async {
    final loaded = await store.loadTheme(id);
    final fallback = id == kFolioDefaultTheme.id
        ? kFolioDefaultTheme
        : ThemeConfig(
            schemaVersion: kFolioDefaultTheme.schemaVersion,
            id: id,
            name: kFolioDefaultTheme.name,
            accentMode: kFolioDefaultTheme.accentMode,
            light: kFolioDefaultTheme.light,
            dark: kFolioDefaultTheme.dark,
            typography: kFolioDefaultTheme.typography,
            shape: kFolioDefaultTheme.shape,
            elevation: kFolioDefaultTheme.elevation,
            spacing: kFolioDefaultTheme.spacing,
            motion: kFolioDefaultTheme.motion,
            icons: kFolioDefaultTheme.icons,
            surfaceOpacity: kFolioDefaultTheme.surfaceOpacity,
          );
    return ThemeConfigController(store, initialConfig: loaded ?? fallback);
  }

  ThemeConfig get config => _config;

  void _update(ThemeConfig next) {
    _config = next;
    notifyListeners();
    _schedulePersist();
  }

  /// Reemplaza el [ThemeConfig] completo, conservando la id activa — mismo
  /// principio que `LayoutEngineController.loadPreset`/
  /// `DashboardGridController.replaceConfig`. Usado por
  /// `AppSettings.onThemeAccentChanged` (accentMode/light/dark) y, más
  /// adelante, por la Fase 8 (instalar un pack visual).
  void replaceConfig(ThemeConfig next) {
    _update(
      ThemeConfig(
        id: _config.id,
        name: next.name,
        accentMode: next.accentMode,
        light: next.light,
        dark: next.dark,
        typography: next.typography,
        shape: next.shape,
        elevation: next.elevation,
        spacing: next.spacing,
        motion: next.motion,
        icons: next.icons,
        surfaceOpacity: next.surfaceOpacity,
      ),
    );
  }

  // ── Editor de temas: campos sin equivalente en AppSettings ───────────

  /// Multiplicador de radio de esquina (1.0 = valores por defecto de
  /// `kFolioDefaultTheme`, no acumulativo entre llamadas).
  void setCornerRoundness(double scale) {
    final base = kFolioDefaultTheme.shape;
    _update(
      _config.copyWith(
        shape: ThemeShapeTokens(
          radiusXs: base.radiusXs * scale,
          radiusSm: base.radiusSm * scale,
          radiusMd: base.radiusMd * scale,
          radiusLg: base.radiusLg * scale,
          radiusXl: base.radiusXl * scale,
          radiusXxl: base.radiusXxl * scale,
          componentRadiusOverrides: _config.shape.componentRadiusOverrides,
        ),
      ),
    );
  }

  /// Multiplicador de densidad de espaciado (1.0 = por defecto).
  void setSpacingDensity(double scale) {
    final base = kFolioDefaultTheme.spacing;
    _update(
      _config.copyWith(
        spacing: ThemeSpacingTokens(
          xxs: base.xxs * scale,
          xs: base.xs * scale,
          sm: base.sm * scale,
          md: base.md * scale,
          lg: base.lg * scale,
          xl: base.xl * scale,
        ),
      ),
    );
  }

  /// Multiplicador de velocidad de movimiento — >1 acorta las duraciones
  /// (más rápido), <1 las alarga (más lento).
  void setMotionSpeed(double scale) {
    final base = kFolioDefaultTheme.motion;
    final safeScale = scale <= 0 ? 1.0 : scale;
    _update(
      _config.copyWith(
        motion: ThemeMotionTokens(
          shortMs: (base.shortMs / safeScale).round(),
          short2Ms: (base.short2Ms / safeScale).round(),
          mediumMs: (base.mediumMs / safeScale).round(),
          themeChangeMs: (base.themeChangeMs / safeScale).round(),
          curveName: _config.motion.curveName,
        ),
      ),
    );
  }

  void setSurfaceOpacity(double opacity) {
    _update(_config.copyWith(surfaceOpacity: opacity.clamp(0.0, 1.0)));
  }

  Future<void> resetToDefault() async {
    _config = ThemeConfig(
      id: _config.id,
      name: kFolioDefaultTheme.name,
      accentMode: _config.accentMode, // conserva acento (viene de AppSettings)
      light: _config.light,
      dark: _config.dark,
      typography: kFolioDefaultTheme.typography,
      shape: kFolioDefaultTheme.shape,
      elevation: kFolioDefaultTheme.elevation,
      spacing: kFolioDefaultTheme.spacing,
      motion: kFolioDefaultTheme.motion,
      icons: kFolioDefaultTheme.icons,
      surfaceOpacity: kFolioDefaultTheme.surfaceOpacity,
    );
    notifyListeners();
    await persist();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, () {
      unawaited(persist());
    });
  }

  Future<void> persist() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    await _store.saveTheme(_config);
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    if (_persistTimer != null) {
      unawaited(_store.saveTheme(_config));
    }
    super.dispose();
  }
}
