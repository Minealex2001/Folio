-- Fase 19–21: tablas/columnas para IA (diagnósticos) e integraciones Slack/Teams/Spotify/Jira.

-- Ampliar índice de usuarios de integración (Firestore integrationUserIndex)
ALTER TABLE integration_user_index
  ADD COLUMN IF NOT EXISTS external_user_id TEXT,
  ADD COLUMN IF NOT EXISTS vault_id TEXT,
  ADD COLUMN IF NOT EXISTS connection_id TEXT,
  ADD COLUMN IF NOT EXISTS webhook_url TEXT,
  ADD COLUMN IF NOT EXISTS teams_security_token TEXT,
  ADD COLUMN IF NOT EXISTS linked_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_integration_user_index_user
  ON integration_user_index(user_id);

-- Ampliar cola de comandos pendientes
ALTER TABLE pending_integration_command
  ADD COLUMN IF NOT EXISTS vault_id TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS error_message TEXT;

CREATE INDEX IF NOT EXISTS idx_pending_integration_command_user_status
  ON pending_integration_command(user_id, status, vault_id);

CREATE TABLE IF NOT EXISTS integration_webhook_connections (
  connection_id TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider      TEXT NOT NULL,
  webhook_url   TEXT NOT NULL,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS integration_link_codes (
  code                   TEXT PRIMARY KEY,
  user_id                TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vault_id               TEXT NOT NULL,
  connection_id          TEXT NOT NULL,
  provider               TEXT NOT NULL,
  webhook_url            TEXT NOT NULL,
  teams_security_token   TEXT,
  expires_at             TIMESTAMPTZ NOT NULL,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS teams_webhook_endpoints (
  connection_id        TEXT PRIMARY KEY,
  user_id              TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  teams_security_token TEXT NOT NULL,
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS folio_diagnostics (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  install_id         TEXT NOT NULL,
  kind               TEXT NOT NULL,
  app_version        TEXT,
  platform           TEXT,
  channel            TEXT,
  user_note          TEXT,
  log_excerpt        TEXT,
  signature          TEXT,
  telemetry_enabled  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS folio_diagnostic_signatures (
  signature           TEXT PRIMARY KEY,
  youtrack_issue_id   TEXT,
  count               INT NOT NULL DEFAULT 1,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
