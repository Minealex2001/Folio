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
