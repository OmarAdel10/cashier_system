-- Daftari cloud schema — auth_users + session provenance (admin-dashboard Phase 1).
-- Apply with: turso db shell <db> < 002_auth_users.sql
-- Run ONCE per environment: the ALTER statements are not re-runnable
-- (libSQL has no ADD COLUMN IF NOT EXISTS) — re-applying fails loudly
-- with 'duplicate column name', which is intended apply-once semantics.
-- Additive DDL — safe to apply while old workers run; required before the
-- first dashboard login (POST /auth/login reads auth_users).

CREATE TABLE IF NOT EXISTS auth_users (
  tenant_id TEXT NOT NULL,
  username TEXT NOT NULL,
  password_hash TEXT NOT NULL,          -- pbkdf2-sha512$<iters>$<salt_b64url>$<hash_b64>
  role TEXT NOT NULL DEFAULT 'admin',  -- 'admin' | 'cashier'
  display_name TEXT,
  must_change_password INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  failed_attempts INTEGER NOT NULL DEFAULT 0,
  locked_until INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (tenant_id, username)
);

ALTER TABLE users ADD COLUMN last_owner_login_at INTEGER;

ALTER TABLE sessions ADD COLUMN source TEXT NOT NULL DEFAULT 'pos';  -- 'pos' | 'web'

CREATE INDEX IF NOT EXISTS idx_sessions_tenant_username
  ON sessions (tenant_id, username);
