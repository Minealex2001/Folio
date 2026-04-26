/// Secretos y overrides solo para desarrollo local.
///
/// **No versionar valores reales.** Copia este archivo a
/// `lib/config/folio_local_secrets.dart` y rellénalo (ese archivo está en
/// `.gitignore`).
///
/// Prioridad respecto a otras fuentes: `--dart-define` > este archivo >
/// `.env` / [LocalEnv] > variables de entorno del proceso.
abstract final class FolioLocalSecrets {
  static const String jiraOAuthClientId = '';
  static const String jiraOAuthClientSecret = '';
  static const String folioIntegrationSecret = '';

  /// Claves alineadas con `String.fromEnvironment` / `.env`.
  static String valueForDefineKey(String key) {
    switch (key) {
      case 'JIRA_OAUTH_CLIENT_ID':
        return jiraOAuthClientId.trim();
      case 'JIRA_OAUTH_CLIENT_SECRET':
        return jiraOAuthClientSecret.trim();
      case 'FOLIO_INTEGRATION_SECRET':
        return folioIntegrationSecret.trim();
      default:
        return '';
    }
  }
}
