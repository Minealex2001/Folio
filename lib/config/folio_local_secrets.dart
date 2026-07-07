/// Secretos locales de desarrollo: **aquí es donde deben vivir** los valores
/// que no quieres versionar (OAuth Jira, integración, etc.).
///
/// **No versionar valores reales.** Rellena este archivo localmente o usa
/// `--dart-define` al compilar. En **web** no hay lectura de `.env` en disco.
///
/// Prioridad: `--dart-define` > `folio_local_secrets.dart` > `.env` / [LocalEnv]
/// (solo escritorio/móvil con dart:io) > variables de entorno del proceso.
abstract final class FolioLocalSecrets {
  static const String jiraOAuthClientId = '';
  static const String jiraOAuthClientSecret = '';
  static const String folioIntegrationSecret = '';
  /// Id de producto Partner Center / enlace apps.microsoft.com/detail/…
  static const String microsoftStoreListingProductId = '';

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
      default:
        return '';
    }
  }
}
