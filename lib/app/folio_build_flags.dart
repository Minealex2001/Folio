/// Build-time UI flags (no vault data).
///
/// Set to `false` for stable releases when you no longer want the BETA strip.
const bool kFolioShowBetaBanner = true;

/// URL para “Reportar bug” (p. ej. GitHub Issues). Sustituible con `--dart-define`.
const String kFolioBugReportUrl = String.fromEnvironment(
  'FOLIO_BUG_REPORT_URL',
  defaultValue: 'https://github.com/Minealex2001/Folio/issues/new',
);
