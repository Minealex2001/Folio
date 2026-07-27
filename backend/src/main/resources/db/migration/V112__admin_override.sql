-- Admin / QA grants that survive Stripe recompute (local & self-host testing).
ALTER TABLE user_folio_cloud
  ADD COLUMN IF NOT EXISTS admin_override BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_user_folio_cloud_admin_override
  ON user_folio_cloud (admin_override)
  WHERE admin_override = TRUE;
