-- Create table for realtime WebSocket tickets
CREATE TABLE IF NOT EXISTS realtime_tickets (
    ticket TEXT PRIMARY KEY NOT NULL,
    tenant_id TEXT NOT NULL,
    expires_at INTEGER NOT NULL,
    used_at INTEGER
);

-- Index for quick lookup by ticket and expiration
CREATE INDEX IF NOT EXISTS idx_realtime_tickets_ticket ON realtime_tickets(ticket);
CREATE INDEX IF NOT EXISTS idx_realtime_tickets_expires ON realtime_tickets(expires_at);
