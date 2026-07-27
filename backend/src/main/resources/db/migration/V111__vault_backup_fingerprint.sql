-- Fase 11/16: fingerprint del cloud-pack (Firestore latestCloudPackContentFingerprint).
ALTER TABLE vault_backups
  ADD COLUMN IF NOT EXISTS content_fingerprint TEXT;

-- Cuota agregada de backup/sync (Firestore users.folioBackup.usedBytes).
CREATE TABLE IF NOT EXISTS user_backup_usage (
  user_id         TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  used_bytes      BIGINT NOT NULL DEFAULT 0,
  purchased_bytes BIGINT NOT NULL DEFAULT 0,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
