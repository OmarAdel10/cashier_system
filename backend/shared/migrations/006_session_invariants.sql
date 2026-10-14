-- Daftari cloud schema — session admission invariants (Task 12).
-- Apply with: turso db shell <db> < 006_session_invariants.sql
-- ADDITIVE and RE-RUNNABLE: no table or column is altered, and the index
-- creation is guarded. Depends on 001_init.sql (sessions table) and
-- 002_auth_users.sql (sessions.source column).

-- Self-heal any duplicate unended web sessions left by the pre-T12
-- count-then-insert race: keep only the most recently started live web row
-- per (tenant_id, username) and end the rest. Without this the unique index
-- below could not be created on an environment that has already raced.
UPDATE sessions
SET ended_at = CAST(strftime('%s', 'now') AS INTEGER) * 1000
WHERE source = 'web'
  AND ended_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM sessions AS newer
    WHERE newer.tenant_id = sessions.tenant_id
      AND newer.username = sessions.username
      AND newer.source = 'web'
      AND newer.ended_at IS NULL
      AND (
        newer.started_at > sessions.started_at
        OR (newer.started_at = sessions.started_at AND newer.id > sessions.id)
      )
  );

-- At most one unended web session per (tenant_id, username). This is what
-- makes POST /auth/login admission atomic: the second concurrent insert hits
-- the constraint, insertSession's ON CONFLICT DO NOTHING reports
-- rowsAffected 0, and the route maps that to 409 SESSION_CONFLICT.
CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_live_web
  ON sessions (tenant_id, username)
  WHERE source = 'web' AND ended_at IS NULL;
