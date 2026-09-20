-- Daftari cloud schema — Turso (libSQL) init migration.
-- Apply with: turso db shell daftari < 001_init.sql

CREATE TABLE IF NOT EXISTS users (
  tenant_id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'admin',
  tier TEXT NOT NULL DEFAULT 'starter',
  display_name TEXT,
  created_at INTEGER NOT NULL,
  last_login_at INTEGER
);

CREATE TABLE IF NOT EXISTS licenses (
  tenant_id TEXT NOT NULL,
  device_hwid TEXT NOT NULL,
  license_key TEXT NOT NULL,
  subscription_end INTEGER NOT NULL,
  billing_cycle TEXT NOT NULL DEFAULT 'monthly',
  grace_end INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at INTEGER NOT NULL,
  PRIMARY KEY (tenant_id, device_hwid)
);

CREATE TABLE IF NOT EXISTS devices (
  tenant_id TEXT NOT NULL,
  device_hwid TEXT NOT NULL,
  device_name TEXT,
  platform TEXT,
  first_seen_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  PRIMARY KEY (tenant_id, device_hwid)
);

CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  device_hwid TEXT NOT NULL,
  username TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  heartbeat_at INTEGER NOT NULL,
  ended_at INTEGER
);

CREATE TABLE IF NOT EXISTS sales (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  receipt_json TEXT NOT NULL,
  total_piastres INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sales_tenant_created ON sales (tenant_id, created_at);
CREATE INDEX IF NOT EXISTS idx_sessions_tenant ON sessions (tenant_id, ended_at);
