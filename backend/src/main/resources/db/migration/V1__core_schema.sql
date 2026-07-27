-- ============ Usuarios y perfil ============
CREATE TABLE users (
  id                  TEXT PRIMARY KEY,
  email               TEXT NOT NULL,
  display_name        TEXT,
  folio_staff         BOOLEAN NOT NULL DEFAULT FALSE,
  stripe_customer_id  TEXT UNIQUE,
  deletion_requested_at TIMESTAMPTZ,
  deletion_scheduled_for TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_users_deletion_scheduled ON users(deletion_scheduled_for) WHERE deletion_scheduled_for IS NOT NULL;

CREATE TABLE user_folio_cloud (
  user_id               TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  subscription_status   TEXT,
  active                BOOLEAN NOT NULL DEFAULT FALSE,
  subscription_price_id TEXT,
  is_family             BOOLEAN NOT NULL DEFAULT FALSE,
  is_student            BOOLEAN NOT NULL DEFAULT FALSE,
  student_verified      BOOLEAN NOT NULL DEFAULT FALSE,
  family_owner_uid      TEXT REFERENCES users(id),
  family_seats          INT NOT NULL DEFAULT 0,
  features              JSONB NOT NULL DEFAULT '{}',
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_user_folio_cloud_active ON user_folio_cloud(active) WHERE active;

CREATE TABLE user_ink (
  user_id            TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  monthly_balance    NUMERIC NOT NULL DEFAULT 0,
  purchased_balance  NUMERIC NOT NULL DEFAULT 0,
  monthly_period_key TEXT,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_billing_stripe (
  user_id           TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  subscription_id   TEXT,
  price_id          TEXT,
  family_seats      INT NOT NULL DEFAULT 0,
  student_verified  BOOLEAN NOT NULL DEFAULT FALSE,
  raw               JSONB NOT NULL DEFAULT '{}'
);

CREATE TABLE user_billing_microsoft_store (
  user_id                     TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  subscription_active         BOOLEAN NOT NULL DEFAULT FALSE,
  subscription_store_product_id TEXT,
  last_validated_at           TIMESTAMPTZ,
  last_item_count             INT
);

-- ============ Familias ============
CREATE TABLE families (
  owner_uid  TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE family_members (
  family_owner_uid TEXT NOT NULL REFERENCES families(owner_uid) ON DELETE CASCADE,
  member_uid       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email_snapshot   TEXT,
  display_name_snapshot TEXT,
  joined_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (family_owner_uid, member_uid)
);

-- ============ Colaboración en tiempo real ============
CREATE TABLE collab_rooms (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_uid          TEXT NOT NULL REFERENCES users(id),
  vault_page_id      TEXT NOT NULL,
  join_code_key      TEXT UNIQUE NOT NULL,
  join_code          TEXT,
  e2e_v              SMALLINT NOT NULL DEFAULT 1,
  content_version    INT NOT NULL DEFAULT 0,
  title              TEXT,
  blocks             JSONB,
  wrapped_room_key   TEXT,
  content_cipher     TEXT,
  updated_by         TEXT REFERENCES users(id),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE collab_room_members (
  room_id    UUID NOT NULL REFERENCES collab_rooms(id) ON DELETE CASCADE,
  member_uid TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, member_uid)
);

CREATE TABLE collab_room_media (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id      UUID NOT NULL REFERENCES collab_rooms(id) ON DELETE CASCADE,
  block_id     TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  media_kind   TEXT NOT NULL,
  size_bytes   BIGINT NOT NULL,
  e2e_v        SMALLINT NOT NULL DEFAULT 1,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE collab_join_attempts (
  uid              TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  attempt_count    INT NOT NULL DEFAULT 0,
  window_started_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============ Publicación web y plantillas comunitarias ============
CREATE TABLE published_pages (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_uid           TEXT NOT NULL REFERENCES users(id),
  storage_path        TEXT NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE community_templates (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_uid              TEXT NOT NULL REFERENCES users(id),
  name                   TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 280),
  description            TEXT CHECK (char_length(description) <= 4000),
  category               TEXT CHECK (char_length(category) <= 120),
  emoji                  TEXT CHECK (char_length(emoji) <= 32),
  block_count            INT NOT NULL CHECK (block_count BETWEEN 0 AND 50000),
  storage_path           TEXT NOT NULL,
  storage_download_url   TEXT NOT NULL CHECK (char_length(storage_download_url) <= 2048),
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============ Idempotencia de pagos ============
CREATE TABLE stripe_webhook_events (
  event_id     TEXT PRIMARY KEY,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE stripe_processed_checkouts (
  session_id   TEXT PRIMARY KEY,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE microsoft_store_processed_purchases (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id),
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE microsoft_store_processed_backup_grants (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id),
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============ Backups de vault ============
CREATE TABLE vault_backups (
  user_id                     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vault_id                    TEXT NOT NULL,
  latest_storage_path         TEXT,
  latest_size_bytes           BIGINT NOT NULL DEFAULT 0,
  cloud_pack_restore_wrap_b64 TEXT,
  cloud_pack_restore_wrap_kind TEXT CHECK (cloud_pack_restore_wrap_kind IN ('vaultDek','packKey')),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, vault_id)
);

CREATE TABLE vault_backup_blobs (
  user_id      TEXT NOT NULL,
  vault_id     TEXT NOT NULL,
  blob_id      TEXT NOT NULL CHECK (blob_id ~ '^[0-9a-f]{64}$'),
  storage_path TEXT NOT NULL,
  size_bytes   BIGINT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, vault_id, blob_id),
  FOREIGN KEY (user_id, vault_id) REFERENCES vault_backups(user_id, vault_id) ON DELETE CASCADE
);

-- ============ Sync de ajustes ============
CREATE TABLE user_app_profile (
  user_id             TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  rev                 INT NOT NULL DEFAULT 0,
  content_fingerprint TEXT NOT NULL,
  pack_storage_path   TEXT NOT NULL,
  pack_size_bytes     BIGINT NOT NULL,
  restore_wrap_b64    TEXT,
  icon_ids            JSONB NOT NULL DEFAULT '[]',
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_vault_profile (
  user_id             TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vault_id            TEXT NOT NULL,
  rev                 INT NOT NULL DEFAULT 0,
  content_fingerprint TEXT NOT NULL,
  pack_storage_path   TEXT NOT NULL,
  pack_size_bytes     BIGINT NOT NULL,
  restore_wrap_b64    TEXT,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, vault_id)
);

CREATE TABLE user_vault_sync (
  user_id                TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vault_id               TEXT NOT NULL,
  rev                    INT NOT NULL DEFAULT 0,
  content_fingerprint    TEXT NOT NULL,
  sync_format_version    SMALLINT NOT NULL DEFAULT 1,
  pack_storage_path      TEXT,
  pack_size_bytes        BIGINT NOT NULL DEFAULT 0,
  manifest_storage_path  TEXT,
  manifest_size_bytes    BIGINT NOT NULL DEFAULT 0,
  device_id              TEXT,
  device_name            TEXT,
  vault_mode             TEXT,
  pack_key_kind          TEXT,
  dek_account_wrap_b64   TEXT,
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, vault_id)
);

CREATE TABLE user_plain_vault_sync_secret (
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vault_id   TEXT NOT NULL,
  secret_b64 TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, vault_id)
);

-- ============ Integraciones ============
CREATE TABLE integration_user_index (
  id             TEXT PRIMARY KEY,
  user_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider       TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE pending_integration_command (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  payload    JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
