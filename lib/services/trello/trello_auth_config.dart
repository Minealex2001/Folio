/// Configuración de la app oficial de Folio en Trello (Power-Up).
abstract final class TrelloAuthConfig {
  /// API Key pública de la app oficial de Folio en Trello.
  ///
  /// No es secreta: Trello la expone en la URL de autorización que el propio
  /// usuario abre en su navegador (`?key=...`), igual que el Client ID de
  /// Jira (`JiraAuthService._officialCloudClientId`). El API Secret de Trello
  /// NO se usa aquí y nunca debe embeberse en una app cliente — el flujo de
  /// token manual de Trello no lo requiere.
  static const String officialApiKey = 'e95987e6b560ad2c3fdd0a066b12539d';
}
