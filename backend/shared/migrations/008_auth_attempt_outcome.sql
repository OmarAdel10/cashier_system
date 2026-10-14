-- Daftari cloud schema — auth attempt outcome (clean-architecture Task 2).
-- Apply with: turso db shell <db> < 008_auth_attempt_outcome.sql
-- ADDITIVE, one-shot schema evolution: one integer column and two guarded
-- indexes. Existing rows default to failures (0) because legacy migration 004
-- did not record outcomes.

ALTER TABLE auth_attempts ADD COLUMN successful INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_auth_attempts_account_failures
  ON auth_attempts (tenant_id, username, successful, attempted_at);

CREATE INDEX IF NOT EXISTS idx_auth_attempts_ip_failures
  ON auth_attempts (ip, successful, attempted_at);
