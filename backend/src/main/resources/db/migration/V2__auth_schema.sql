-- Auth schema: password, status, verification / reset / refresh tokens

ALTER TABLE users
  ADD COLUMN password_hash TEXT NOT NULL DEFAULT '',
  ADD COLUMN email_verified_at TIMESTAMPTZ,
  ADD COLUMN status TEXT NOT NULL DEFAULT 'active';

-- Remove temporary default after backfill of empty string for existing rows (none in greenfield).
ALTER TABLE users ALTER COLUMN password_hash DROP DEFAULT;

CREATE UNIQUE INDEX idx_users_email_lower ON users (lower(email));

CREATE TABLE refresh_tokens (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash    TEXT NOT NULL UNIQUE,
  expires_at    TIMESTAMPTZ NOT NULL,
  revoked_at    TIMESTAMPTZ,
  replaced_by   UUID,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  device_label  TEXT
);
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);

CREATE TABLE email_verification_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_email_verification_tokens_user_id ON email_verification_tokens(user_id);

CREATE TABLE password_reset_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_password_reset_tokens_user_id ON password_reset_tokens(user_id);
