-- Daftari cloud schema — login throttling (Task 17 / DAFTARI-97).
-- Apply with: turso db shell <db> < 004_login_throttle.sql
-- ADDITIVE and RE-RUNNABLE: new table + guarded indexes only; no existing
-- table or column is altered. Standalone (no FK) so it can be applied
-- before or after the sessions/auth_users work.

-- One row per login attempt that was ADMITTED by the rate limiter. The
-- limiter reads two sliding windows over this log: per ip and per
-- (tenant_id, username). Rejected attempts are not written, so a hostile
-- caller cannot indefinitely extend its own window.
CREATE TABLE IF NOT EXISTS auth_attempts (
  id INTEGER PRIMARY KEY,
  ip TEXT NOT NULL,
  tenant_id TEXT NOT NULL,
  username TEXT NOT NULL,
  attempted_at INTEGER NOT NULL
);

-- The two limiter reads each get a covering index on (key..., attempted_at).
CREATE INDEX IF NOT EXISTS idx_auth_attempts_ip
  ON auth_attempts (ip, attempted_at);

CREATE INDEX IF NOT EXISTS idx_auth_attempts_account
  ON auth_attempts (tenant_id, username, attempted_at);
