/// Fases del arranque tolerante a fallos de Folio.
enum BootstrapPhase {
  config,
  logging,
  settings,
  vaultRegistry,
  vaultOpen,
  desktop,
  firebase,
  ai,
  deviceSync,
  integrations,
  background,
  ready,
  recovery,
}
