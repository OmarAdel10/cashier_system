-- Daftari cloud schema — one live POS session per device (Task 3).
-- Apply with: turso db shell <db> < 009_pos_unique_live_session.sql
-- ADDITIVE and RE-RUNNABLE: no table or column is altered, and index creation
-- is guarded. Depends on 001_init.sql (sessions table).

CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_live_pos_device
  ON sessions (tenant_id, device_hwid)
  WHERE source = 'pos' AND ended_at IS NULL;
