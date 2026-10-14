-- Daftari cloud schema — lockout reservation (Task 40).
-- Apply with: turso db shell <db> < 005_lock_reservation.sql
-- ADDITIVE and RE-RUNNABLE: new table + id column; no existing table or column is altered.
CREATE TABLE IF NOT EXISTS auth_lock_reservations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id TEXT NOT NULL,
  username TEXT NOT NULL,
  reserved_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_auth_lock_reservations ON auth_lock_reservations (tenant_id, username, reserved_at);