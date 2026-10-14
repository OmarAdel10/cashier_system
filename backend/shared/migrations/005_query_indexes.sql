-- Daftari cloud schema — query indexes for hot per-tenant reads (Task 24).
-- Apply with: turso db shell <db> < 005_query_indexes.sql
-- ADDITIVE and RE-RUNNABLE: every statement is CREATE INDEX IF NOT EXISTS,
-- so this file is safe to apply more than once and safe to apply while old
-- workers are running. No tables or columns are altered here.

-- Sessions are listed per tenant ordered by started_at
-- (getActiveSessions / getRecentSessions in src/turso.ts).
CREATE INDEX IF NOT EXISTS idx_sessions_tenant_started
  ON sessions (tenant_id, started_at);

-- Devices are listed per tenant ordered by last_seen_at.
CREATE INDEX IF NOT EXISTS idx_devices_tenant_last_seen
  ON devices (tenant_id, last_seen_at);
