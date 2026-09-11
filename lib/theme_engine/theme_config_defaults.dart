import '../app/folio_brand_palette.dart';
import '../config/models/theme_config.dart';

/// `ThemeConfig` que reproduce exactamente los valores hoy hardcodeados en
/// `folio_theme.dart`/`AppSettings` — accentMode 'followSystem', tokens de
/// forma/espaciado/elevación/movimiento con los mismos valores que
/// `FolioRadius`/`FolioSpace`/`FolioElevation`/`FolioMotion`
/// (`lib/app/ui_tokens.dart`), sin override de fuente (usa Outfit vía
/// `google_fonts`, igual que hoy). Es el punto de partida — instalar
/// cualquier pack visual (Fase 8) reemplaza este `ThemeConfig`, nunca lo
/// modifica en el sitio.
final ThemeConfig kFolioDefaultTheme = ThemeConfig.fallbackDefault(
  id: 'default',
  seedArgb: kFolioBrandPrimaryArgb,
  accentMode: 'followSystem',
);
