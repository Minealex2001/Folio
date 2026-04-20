import '../../models/folio_app_package.dart';

/// Catálogo de apps oficiales integradas en Folio.
///
/// Estas apps no requieren descarga ni archivo .folioapp — se instalan
/// directamente desde la Tienda de Apps con un solo tap y su lógica
/// vive en el código nativo de Folio.
abstract class FolioBuiltInApps {
  // ── IDs canónicos ─────────────────────────────────────────────────────────

  static const String jiraId = 'com.folio.integrations.jira';

  // ── Definiciones de paquete ───────────────────────────────────────────────

  static const FolioAppPackage jira = FolioAppPackage(
    id: jiraId,
    name: 'Jira',
    version: '1.0.0',
    author: 'Folio',
    description:
        'Sincroniza issues de Jira Cloud o Server/DC con tableros Kanban en Folio. '
        'Crea issues, filtra por proyecto y visualiza tu backlog directamente desde el editor.',
    iconUrl: '',
    websiteUrl: 'https://www.atlassian.com/software/jira',
    isBuiltIn: true,
    permissions: [FolioAppPermission.internet],
  );

  // ── Lista completa ────────────────────────────────────────────────────────

  /// Todas las apps oficiales integradas en Folio.
  static const List<FolioAppPackage> all = [jira];
}
