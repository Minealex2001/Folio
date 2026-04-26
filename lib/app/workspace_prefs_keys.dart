/// Claves de preferencias compartidas entre [AppSettings] y [VaultSession].
abstract final class WorkspacePrefsKeys {
  static const openWorkspaceToHome = 'folio_workspace_open_to_home';

  static String homeOnboardAnchor(String vaultId) =>
      'folio_ws_home_onboard_anchor_${vaultId.trim()}';

  static String homeOnboardDismissed(String vaultId) =>
      'folio_ws_home_onboard_dismiss_${vaultId.trim()}';
}
