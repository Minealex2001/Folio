/// Placeholders de secretos locales (OAuth Jira, integración, etc.).
///
/// **Este archivo SÍ está versionado en git, con valores vacíos.** No lo
/// edites con valores reales y luego hagas commit — usa `--dart-define` al
/// compilar para secretos reales; es la única vía pensada para no arriesgar
/// que un `git add -A` local suba un secreto por accidente. En **web** no hay
/// lectura de `.env` en disco, así que `--dart-define` es obligatorio ahí.
///
/// Prioridad: `--dart-define` > `folio_local_secrets.dart` > `.env` / [LocalEnv]
/// (solo escritorio/móvil con dart:io) > variables de entorno del proceso.
abstract final class FolioLocalSecrets {
  static const String jiraOAuthClientId = '';
  static const String jiraOAuthClientSecret = '';
  static const String folioIntegrationSecret = '';
  /// Id de producto Partner Center / enlace apps.microsoft.com/detail/…
  static const String microsoftStoreListingProductId = '';
  static const String spotifyOAuthClientId = '931f461da7fe4c31872c1d09277329f9';
  static const String slackOAuthClientId = '';
  static const String teamsOAuthClientId = '';

  /// Folio Cloud Spring: `spring` | vacío (= Firebase). Sobrescribible con
  /// `--dart-define=FOLIO_BACKEND_MODE=…`.
  /// Para Railway: pon `spring` y la URL pública en [folioBackendBaseUrl].
  static const String folioBackendMode = 'spring';

  /// URL pública del API (Railway o local). Sin barra final.
  /// Ejemplo Railway: `https://folio-backend-production-xxxx.up.railway.app`
  /// Ejemplo local: `http://127.0.0.1:18080`
  ///
  /// Default = backend de beta (no el de producción): esto es lo que se usa
  /// cuando no hay `--dart-define=FOLIO_BACKEND_BASE_URL=…` (p. ej. `flutter
  /// run` en local, o builds de prerelease). La release estable oficial
  /// (`windows-release-on-merge.yml`) sobrescribe explícitamente con el
  /// backend de producción — ver ese workflow y `builld_all.ps1`.
  static const String folioBackendBaseUrl =
      'https://api-beta.folio.com.es';

  /// Mismas claves que `String.fromEnvironment` y las entradas de `.env`.
  static String valueForDefineKey(String key) {
    switch (key) {
      case 'JIRA_OAUTH_CLIENT_ID':
        return jiraOAuthClientId.trim();
      case 'JIRA_OAUTH_CLIENT_SECRET':
        return jiraOAuthClientSecret.trim();
      case 'FOLIO_INTEGRATION_SECRET':
        return folioIntegrationSecret.trim();
      case 'FOLIO_MS_STORE_LISTING_PRODUCT_ID':
        return microsoftStoreListingProductId.trim();
      case 'SPOTIFY_OAUTH_CLIENT_ID':
        return spotifyOAuthClientId.trim();
      case 'SLACK_OAUTH_CLIENT_ID':
        return slackOAuthClientId.trim();
      case 'TEAMS_OAUTH_CLIENT_ID':
        return teamsOAuthClientId.trim();
      case 'FOLIO_BACKEND_MODE':
        return folioBackendMode.trim();
      case 'FOLIO_BACKEND_BASE_URL':
        return folioBackendBaseUrl.trim();
      default:
        return '';
    }
  }
}
