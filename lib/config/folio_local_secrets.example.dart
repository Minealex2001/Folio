/// Secretos locales de desarrollo: **aquí es donde deben vivir** los valores
/// que no quieres versionar (OAuth Jira, integración, etc.).
///
/// **No versionar valores reales.** Copia este archivo a
/// `lib/config/folio_local_secrets.dart` y rellénalo (ese archivo está en
/// `.gitignore`). En **web** no hay lectura de `.env` en disco: usa ese archivo
/// o `--dart-define` al compilar.
///
/// Prioridad: `--dart-define` > `folio_local_secrets.dart` > `.env` / [LocalEnv]
/// (solo escritorio/móvil con dart:io) > variables de entorno del proceso.
abstract final class FolioLocalSecrets {
  static const String jiraOAuthClientId = '';
  static const String jiraOAuthClientSecret = '';
  static const String folioIntegrationSecret = '';
  /// Id de producto Partner Center / enlace apps.microsoft.com/detail/…
  static const String microsoftStoreListingProductId = '';
  static const String spotifyOAuthClientId = '';
  static const String slackOAuthClientId = '';
  static const String teamsOAuthClientId = '';

  /// Folio Cloud Spring: `spring` | vacío (= Firebase).
  static const String folioBackendMode = '';

  /// URL del API Spring (Railway o `http://127.0.0.1:18080`).
  static const String folioBackendBaseUrl = '';

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
