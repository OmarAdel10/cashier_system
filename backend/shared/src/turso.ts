/**
 * Turso (libSQL) cloud database client for Cloudflare Workers.
 *
 * Wraps @libsql/client (HTTP transport, Worker-compatible) with typed,
 * idempotent helpers for users, licenses, devices, sessions, and sales.
 */
import { createClient } from '@libsql/client';
import type { Client, InValue, ResultSet } from '@libsql/client';
import type {
  AuthUserRecord,
  DeviceRecord,
  LicenseRecord,
  NewAuthUser,
  SaleRecord,
  SessionRecord,
  UserProfile,
} from './types';
import type { AuthAttemptWindow } from './rate_limit';

export function createTurso(url: string, authToken: string): TursoDb {
  const client: Client = createClient({ url, authToken });
  return new TursoDb(client);
}

/**
 * POS username-conflict window: `getActiveSessionsForUsername` treats a POS
 * session whose heartbeat is older than this as no longer occupying the
 * username, so a re-login on another device is not blocked by a dead row.
 *
 * This is deliberately NOT a web-session liveness rule. The admin dashboard
 * never calls POST /sessions/heartbeat, so a web row's heartbeat_at is stamped
 * once at login and never refreshed; gating web auth on it would 401 every
 * admin request SESSION_FRESH_MS after login, active or idle. Web liveness is
 * (tenant, session id, ended_at IS NULL), bounded by the session JWT's own
 * `exp`.
 */
export const SESSION_FRESH_MS = 5 * 60 * 1000;

export class TursoDb {
  constructor(private readonly client: Client) {}

  private async exec(sql: string, args: InValue[] = []): Promise<ResultSet> {
    return this.client.execute({ sql, args });
  }

  // ---- users ----

  async upsertUser(user: {
    tenant_id: string;
    email: string;
    role: string;
    created_at: number;
    display_name?: string;
  }): Promise<void> {
    await this.exec(
      `INSERT INTO users (tenant_id, email, role, display_name, created_at, last_login_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT (tenant_id) DO UPDATE SET email = excluded.email, last_login_at = excluded.last_login_at`,
      [user.tenant_id, user.email, user.role, user.display_name ?? null, user.created_at, Date.now()],
    );
  }

  async getUser(tenantId: string): Promise<UserProfile | null> {
    const res = await this.exec(`SELECT * FROM users WHERE tenant_id = ?`, [tenantId]);
    const row = res.rows[0] as unknown as Record<string, unknown> | undefined;
    if (!row) return null;
    return {
      tenant_id: String(row['tenant_id']),
      email: String(row['email'] ?? ''),
      role: String(row['role'] ?? ''),
      tier: String(row['tier'] ?? 'starter'),
      display_name: row['display_name'] != null ? String(row['display_name']) : undefined,
      created_at: Number(row['created_at'] ?? 0),
      last_login_at: row['last_login_at'] != null ? Number(row['last_login_at']) : undefined,
      last_owner_login_at:
        row['last_owner_login_at'] != null ? Number(row['last_owner_login_at']) : undefined,
    };
  }

  /** Stamps the tenant row after a successful owner (Stage-1) login. */
  async touchOwnerLogin(tenantId: string, at: number): Promise<void> {
    await this.exec(`UPDATE users SET last_owner_login_at = ? WHERE tenant_id = ?`, [at, tenantId]);
  }

  // ---- licenses ----

  async upsertLicense(license: LicenseRecord): Promise<void> {
    await this.exec(
      `INSERT INTO licenses (tenant_id, device_hwid, license_key, subscription_end, billing_cycle, grace_end, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT (tenant_id, device_hwid) DO UPDATE SET
         license_key = excluded.license_key,
         subscription_end = excluded.subscription_end,
         billing_cycle = excluded.billing_cycle,
         grace_end = excluded.grace_end,
         status = excluded.status`,
      [
        license.tenant_id,
        license.device_hwid,
        license.license_key,
        license.subscription_end,
        license.billing_cycle,
        license.grace_end,
        license.status,
        license.created_at,
      ],
    );
  }

  async getLicense(tenantId: string, deviceHwid: string): Promise<LicenseRecord | null> {
    const res = await this.exec(
      `SELECT * FROM licenses WHERE tenant_id = ? AND device_hwid = ?`,
      [tenantId, deviceHwid],
    );
    const row = res.rows[0] as unknown as Record<string, unknown> | undefined;
    if (!row) return null;
    return this.toLicense(row);
  }

  /** Most recently created license for the tenant (for /auth/me + sync). */
  async getLatestLicense(tenantId: string): Promise<LicenseRecord | null> {
    const res = await this.exec(
      `SELECT * FROM licenses WHERE tenant_id = ? ORDER BY created_at DESC LIMIT 1`,
      [tenantId],
    );
    const row = res.rows[0] as unknown as Record<string, unknown> | undefined;
    if (!row) return null;
    return this.toLicense(row);
  }

  private toLicense(row: Record<string, unknown>): LicenseRecord {
    return {
      tenant_id: String(row['tenant_id']),
      device_hwid: String(row['device_hwid']),
      license_key: String(row['license_key']),
      subscription_end: Number(row['subscription_end'] ?? 0),
      billing_cycle: String(row['billing_cycle']) as LicenseRecord['billing_cycle'],
      grace_end: Number(row['grace_end'] ?? 0),
      status: String(row['status']) as LicenseRecord['status'],
      created_at: Number(row['created_at'] ?? 0),
    };
  }

  /** Cron sweep: licenses whose grace period has ended → expired.
   *  grace_end = 0 is the lifetime sentinel — never expires. */
  async sweepExpiredLicenses(now: number): Promise<void> {
    await this.exec(
      `UPDATE licenses SET status = 'expired' WHERE grace_end > 0 AND grace_end < ? AND status != 'expired'`,
      [now],
    );
  }

  // ---- devices ----

  async upsertDevice(device: DeviceRecord): Promise<void> {
    await this.exec(
      `INSERT INTO devices (tenant_id, device_hwid, device_name, platform, first_seen_at, last_seen_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT (tenant_id, device_hwid) DO UPDATE SET
         device_name = COALESCE(excluded.device_name, devices.device_name),
         platform = COALESCE(excluded.platform, devices.platform),
         last_seen_at = excluded.last_seen_at`,
      [
        device.tenant_id,
        device.device_hwid,
        device.device_name ?? null,
        device.platform ?? null,
        device.first_seen_at,
        device.last_seen_at,
      ],
    );
  }

  private toDevice(row: unknown): DeviceRecord {
    const r = row as unknown as Record<string, unknown>;
    return {
      tenant_id: String(r['tenant_id']),
      device_hwid: String(r['device_hwid']),
      device_name: r['device_name'] != null ? String(r['device_name']) : undefined,
      platform: r['platform'] != null ? String(r['platform']) : undefined,
      first_seen_at: Number(r['first_seen_at'] ?? 0),
      last_seen_at: Number(r['last_seen_at'] ?? 0),
    };
  }

  async listDevices(tenantId: string): Promise<DeviceRecord[]> {
    const res = await this.exec(
      `SELECT * FROM devices WHERE tenant_id = ? ORDER BY last_seen_at DESC`,
      [tenantId],
    );
    return res.rows.map((row) => this.toDevice(row));
  }

  // ---- sessions ----

  /** Inserts a session row. Returns false when the row was NOT written: the
   *  partial unique index idx_sessions_live_web rejects a second unended web
   *  row for the same (tenant, username), which is exactly the concurrent
   *  login race (T12). ON CONFLICT DO NOTHING makes the insert idempotent
   *  rather than throwing, so the caller can surface a 409 instead of minting
   *  a token for a row that does not exist. */
  async insertSession(session: SessionRecord): Promise<boolean> {
    const res = await this.exec(
      `INSERT INTO sessions (id, tenant_id, device_hwid, username, started_at, heartbeat_at, source)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT DO NOTHING`,
      [
        session.id,
        session.tenant_id,
        session.device_hwid,
        session.username,
        session.started_at,
        session.heartbeat_at,
        session.source ?? 'pos',
      ],
    );
    return res.rowsAffected > 0;
  }

  /** Atomic POS device admission (T12). The slot check and the insert are a
   *  single SQL statement, so two concurrent POST /sessions/start calls cannot
   *  both observe a free slot and both insert past the tenant's limit. Admits
   *  a reconnect to a device_hwid that already holds a live POS session, or a
   *  new device while the tenant's live POS count is below [limit]. Returns
   *  false when the statement wrote no row (limit reached). */
  async admitPosSession(session: SessionRecord, limit: number): Promise<boolean> {
    const res = await this.exec(
      `INSERT INTO sessions (id, tenant_id, device_hwid, username, started_at, heartbeat_at, source)
       SELECT ?, ?, ?, ?, ?, ?, 'pos'
       WHERE EXISTS (
         SELECT 1 FROM sessions
         WHERE tenant_id = ? AND device_hwid = ? AND ended_at IS NULL
           AND (source IS NULL OR source != 'web')
       )
       OR (
         SELECT COUNT(*) FROM sessions
         WHERE tenant_id = ? AND ended_at IS NULL
           AND (source IS NULL OR source != 'web')
       ) < ?`,
      [
        session.id,
        session.tenant_id,
        session.device_hwid,
        session.username,
        session.started_at,
        session.heartbeat_at,
        session.tenant_id,
        session.device_hwid,
        session.tenant_id,
        limit,
      ],
    );
    return res.rowsAffected > 0;
  }

  /** Refreshes one session's heartbeat, scoped to its owning tenant (T13
   *  IDOR): the id alone is never enough, so a caller cannot touch another
   *  tenant's row. Returns false when no open row matched (unknown, foreign,
   *  or already ended). */
  async heartbeatSession(sessionId: string, tenantId: string, at: number): Promise<boolean> {
    const res = await this.exec(
      `UPDATE sessions SET heartbeat_at = ? WHERE id = ? AND tenant_id = ? AND ended_at IS NULL`,
      [at, sessionId, tenantId],
    );
    return res.rowsAffected > 0;
  }

  /** Ends one session, scoped to its owning tenant (T13 IDOR). Returns false
   *  when no open row matched, so the route can answer 404 instead of
   *  pretending a foreign id was closed. */
  async endSession(sessionId: string, tenantId: string, at: number): Promise<boolean> {
    const res = await this.exec(
      `UPDATE sessions SET ended_at = ? WHERE id = ? AND tenant_id = ? AND ended_at IS NULL`,
      [at, sessionId, tenantId],
    );
    return res.rowsAffected > 0;
  }

  /** Ends one session, scoped to its owning tenant. Used by POST /auth/logout:
   *  the id AND tenant come from the verified token, so a caller can never
   *  touch another tenant's row. `ended_at IS NULL` makes it idempotent. */
  async endSessionForTenant(sessionId: string, tenantId: string, at: number): Promise<void> {
    await this.endSession(sessionId, tenantId, at);
  }

  /** Ends the POS session for a given device_hwid in the tenant.
   *  Used on reconnect so the same device doesn't consume a second slot. */
  async endSessionForDevice(tenantId: string, deviceHwid: string, at: number): Promise<void> {
    await this.exec(
      `UPDATE sessions SET ended_at = ? WHERE tenant_id = ? AND device_hwid = ? AND source = 'pos' AND ended_at IS NULL`,
      [at, tenantId, deviceHwid],
    );
  }

  /** Live web-session lookup for the auth gate. Returns the row only when it
   *  belongs to [tenantId] and is unended; null otherwise.
   *
   *  Web sessions never heartbeat (the dashboard has no heartbeat call), so
   *  heartbeat freshness plays no part here. The session JWT's own `exp` bounds
   *  the lifetime and revocation is expressed as ended_at (there is no separate
   *  revoked flag), so an ended row is a revoked session and any other existing
   *  row is live. The SESSION_FRESH_MS rule belongs to the POS username-
   *  conflict check (`getActiveSessionsForUsername`) and deliberately does NOT
   *  gate web sessions. */
  async getLiveWebSession(tenantId: string, sessionId: string): Promise<SessionRecord | null> {
    const res = await this.exec(
      `SELECT * FROM sessions WHERE id = ? AND tenant_id = ? AND ended_at IS NULL`,
      [sessionId, tenantId],
    );
    const row = res.rows[0];
    return row ? this.toSession(row) : null;
  }

  async getActiveSessions(tenantId: string): Promise<SessionRecord[]> {
    const res = await this.exec(
      `SELECT * FROM sessions WHERE tenant_id = ? AND ended_at IS NULL ORDER BY started_at ASC`,
      [tenantId],
    );
    return res.rows.map((row) => this.toSession(row));
  }

  /** Open sessions for one username with a heartbeat newer than
   *  [heartbeatSince] — the per-username conflict check (spec §6.5). */
  async getActiveSessionsForUsername(
    tenantId: string,
    username: string,
    heartbeatSince: number,
  ): Promise<SessionRecord[]> {
    const res = await this.exec(
      `SELECT * FROM sessions WHERE tenant_id = ? AND username = ? AND ended_at IS NULL AND heartbeat_at > ? ORDER BY started_at ASC`,
      [tenantId, username, heartbeatSince],
    );
    return res.rows.map((row) => this.toSession(row));
  }

  /** Latest sessions for the tenant's activity feed (any ended-state). */
  async getRecentSessions(tenantId: string, limit: number): Promise<SessionRecord[]> {
    const res = await this.exec(
      `SELECT * FROM sessions WHERE tenant_id = ? ORDER BY started_at DESC LIMIT ?`,
      [tenantId, limit],
    );
    return res.rows.map((row) => this.toSession(row));
  }

  /** Ends every unended web session for (tenant, username) — called at
   *  login success so dashboard rows never accumulate or outlive their
   *  replacement (T06 QA finding F1). */
  async endWebSessions(tenantId: string, username: string, at: number): Promise<void> {
    await this.exec(
      `UPDATE sessions SET ended_at = ? WHERE tenant_id = ? AND username = ? AND source = 'web' AND ended_at IS NULL`,
      [at, tenantId, username],
    );
  }

  /** Device-limit count for /sessions/start: POS sessions only —
   *  web dashboard logins are not devices (T06 QA finding F1).
   *  T22: only count sessions with a fresh heartbeat (stale rows freed). */
  async getActivePosSessions(tenantId: string): Promise<SessionRecord[]> {
    const res = await this.exec(
      `SELECT * FROM sessions WHERE tenant_id = ? AND ended_at IS NULL AND (source IS NULL OR source != 'web') AND heartbeat_at > ? ORDER BY started_at ASC`,
      [tenantId, Date.now() - SESSION_FRESH_MS],
    );
    return res.rows.map((row) => this.toSession(row));
  }

  private toSession(row: unknown): SessionRecord {
    const r = row as unknown as Record<string, unknown>;
    return {
      id: String(r['id']),
      tenant_id: String(r['tenant_id']),
      device_hwid: String(r['device_hwid']),
      username: String(r['username'] ?? ''),
      started_at: Number(r['started_at'] ?? 0),
      heartbeat_at: Number(r['heartbeat_at'] ?? 0),
      ended_at: r['ended_at'] != null ? Number(r['ended_at']) : undefined,
      source: r['source'] != null ? String(r['source']) : undefined,
    };
  }

  // ---- sales ----

  async insertSale(sale: SaleRecord): Promise<void> {
    await this.exec(
      `INSERT OR REPLACE INTO sales (id, tenant_id, receipt_json, total_piastres, created_at)
       VALUES (?, ?, ?, ?, ?)`,
      [sale.id, sale.tenant_id, sale.receipt_json, sale.total_piastres, sale.created_at],
    );
  }

  async listSales(tenantId: string, since: number): Promise<SaleRecord[]> {
    const res = await this.exec(
      `SELECT * FROM sales WHERE tenant_id = ? AND created_at > ? ORDER BY created_at ASC`,
      [tenantId, since],
    );
    return res.rows.map((row) => {
      const r = row as unknown as Record<string, unknown>;
      return {
        id: String(r['id']),
        tenant_id: String(r['tenant_id']),
        receipt_json: String(r['receipt_json'] ?? '{}'),
        total_piastres: Number(r['total_piastres'] ?? 0),
        created_at: Number(r['created_at'] ?? 0),
      };
    });
  }

  async getTenantStats(tenantId: string): Promise<{ saleCount: number; totalPiastres: number }> {
    const res = await this.exec(
      `SELECT COUNT(*) AS sale_count, COALESCE(SUM(total_piastres), 0) AS total FROM sales WHERE tenant_id = ?`,
      [tenantId],
    );
    const row = res.rows[0] as unknown as Record<string, unknown> | undefined;
    return {
      saleCount: Number(row?.['sale_count'] ?? 0),
      totalPiastres: Number(row?.['total'] ?? 0),
    };
  }

  // ---- auth_users (dashboard + cashier accounts, admin-dashboard T04) ----

  private toAuthUser(row: unknown): AuthUserRecord {
    const r = row as unknown as Record<string, unknown>;
    return {
      tenant_id: String(r['tenant_id']),
      username: String(r['username']),
      password_hash: String(r['password_hash'] ?? ''),
      role: String(r['role'] ?? ''),
      display_name: r['display_name'] != null ? String(r['display_name']) : undefined,
      must_change_password: Number(r['must_change_password'] ?? 0),
      is_active: Number(r['is_active'] ?? 1),
      failed_attempts: Number(r['failed_attempts'] ?? 0),
      locked_until: r['locked_until'] != null ? Number(r['locked_until']) : undefined,
      created_at: Number(r['created_at'] ?? 0),
      updated_at: Number(r['updated_at'] ?? 0),
    };
  }

  async getAuthUser(tenantId: string, username: string): Promise<AuthUserRecord | null> {
    const res = await this.exec(
      `SELECT * FROM auth_users WHERE tenant_id = ? AND username = ?`,
      [tenantId, username],
    );
    const row = res.rows[0];
    return row ? this.toAuthUser(row) : null;
  }

  async listAuthUsers(tenantId: string): Promise<AuthUserRecord[]> {
    const res = await this.exec(
      `SELECT * FROM auth_users WHERE tenant_id = ? ORDER BY username ASC`,
      [tenantId],
    );
    return res.rows.map((row) => this.toAuthUser(row));
  }

  async insertAuthUser(user: NewAuthUser): Promise<void> {
    const now = Date.now();
    await this.exec(
      `INSERT INTO auth_users
         (tenant_id, username, password_hash, role, display_name, must_change_password,
          is_active, failed_attempts, locked_until, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        user.tenant_id,
        user.username,
        user.password_hash,
        user.role,
        user.display_name ?? null,
        user.must_change_password ?? 0,
        1,
        0,
        null,
        now,
        now,
      ],
    );
  }

  async updateAuthUser(
    tenantId: string,
    username: string,
    patch: { password_hash?: string; display_name?: string; is_active?: number },
  ): Promise<void> {
    const sets: string[] = [];
    const args: InValue[] = [];
    if (patch.password_hash !== undefined) {
      sets.push('password_hash = ?');
      args.push(patch.password_hash);
    }
    if (patch.display_name !== undefined) {
      sets.push('display_name = ?');
      args.push(patch.display_name);
    }
    if (patch.is_active !== undefined) {
      sets.push('is_active = ?');
      args.push(patch.is_active);
    }
    sets.push('updated_at = ?');
    args.push(Date.now(), tenantId, username);
    await this.exec(
      `UPDATE auth_users SET ${sets.join(', ')} WHERE tenant_id = ? AND username = ?`,
      args,
    );
  }

  /** Persists one failed login attempt (counter +1, SQL-side atomic) and
   *  computes the lock deadline based on the new count. */
  async recordAuthFailure(
    tenantId: string,
    username: string,
  ): Promise<void> {
    await this.exec(
      `UPDATE auth_users SET 
        failed_attempts = failed_attempts + 1,
        locked_until = CASE 
          WHEN (failed_attempts + 1) >= 3 
          THEN (strftime('%s', 'now') * 1000) + MIN(2 ** (failed_attempts + 1) * 15000, 900000)
          ELSE NULL 
        END,
        updated_at = ? 
      WHERE tenant_id = ? AND username = ?`,
      [Date.now(), tenantId, username],
    );
  }

  /** Attempt to reserve a login attempt for (tenant, username).
   *  Returns true if reservation written (under the limit), false if at/over limit.
   *  Must be called BEFORE password verification. */
  async reserveLoginAttempt(tenantId: string, username: string): Promise<boolean> {
    const res = await this.exec(
      `INSERT INTO auth_lock_reservations (tenant_id, username, reserved_at)
       SELECT ?, ?, ?
       WHERE (
         SELECT COUNT(*) FROM auth_lock_reservations
         WHERE tenant_id = ? AND username = ? AND reserved_at > strftime('%s', 'now') * 1000 - 900000
       ) < 5`,
      [tenantId, username, Date.now(), tenantId, username],
    );
    return res.rowsAffected > 0;
  }

  /** Release a previously made reservation for (tenant, username). */
  async releaseLoginAttempt(tenantId: string, username: string): Promise<void> {
    await this.exec(
      `DELETE FROM auth_lock_reservations
       WHERE tenant_id = ? AND username = ?
       ORDER BY reserved_at DESC LIMIT 1`,
      [tenantId, username],
    );
  }

  /** Convert the most recent reservation for (tenant, username) into a recorded failure.
   *  This should be called on password failure after a successful reservation. */
  async convertReservationToFailure(tenantId: string, username: string): Promise<void> {
    await this.exec(
      `UPDATE auth_users SET
        failed_attempts = failed_attempts + 1,
        locked_until = CASE 
          WHEN (failed_attempts + 1) >= 3 
          THEN (strftime('%s', 'now') * 1000) + MIN(2 ** (failed_attempts + 1) * 15000, 900000)
          ELSE NULL 
        END,
        updated_at = ?
       WHERE tenant_id = ? AND username = ?`,
      [Date.now(), tenantId, username],
    );
    await this.exec(
      `DELETE FROM auth_lock_reservations
       WHERE tenant_id = ? AND username = ?
       ORDER BY reserved_at DESC LIMIT 1`,
      [tenantId, username],
    );
  }

  async resetAuthFailures(tenantId: string, username: string): Promise<void> {
    await this.exec(
      `UPDATE auth_users SET failed_attempts = 0, locked_until = NULL, updated_at = ? WHERE tenant_id = ? AND username = ?`,
      [Date.now(), tenantId, username],
    );
  }

  // ---- auth_attempts (login throttling, migration 004 / T17) ----

  /** Appends one admitted login attempt to the throttling log. */
  async recordAuthAttempt(
    ip: string,
    tenantId: string,
    username: string,
    at: number,
  ): Promise<void> {
    await this.exec(
      `INSERT INTO auth_attempts (ip, tenant_id, username, attempted_at) VALUES (?, ?, ?, ?)`,
      [ip, tenantId, username, at],
    );
  }

  /** COUNT + MIN(attempted_at) for one sliding window predicate. */
  private async attemptWindow(sql: string, args: InValue[]): Promise<AuthAttemptWindow> {
    const res = await this.exec(sql, args);
    const row = res.rows[0] as unknown as Record<string, unknown> | undefined;
    return {
      count: Number(row?.['n'] ?? 0),
      oldestAt: row?.['oldest'] != null ? Number(row['oldest']) : null,
    };
  }

  /** Attempts admitted from [ip] strictly after [since]. */
  async countAuthAttemptsByIp(ip: string, since: number): Promise<AuthAttemptWindow> {
    return this.attemptWindow(
      `SELECT COUNT(*) AS n, MIN(attempted_at) AS oldest FROM auth_attempts WHERE ip = ? AND attempted_at > ?`,
      [ip, since],
    );
  }

  /** Attempts admitted for (tenant, username) strictly after [since]. */
  async countAuthAttemptsByAccount(
    tenantId: string,
    username: string,
    since: number,
  ): Promise<AuthAttemptWindow> {
    return this.attemptWindow(
      `SELECT COUNT(*) AS n, MIN(attempted_at) AS oldest FROM auth_attempts WHERE tenant_id = ? AND username = ? AND attempted_at > ?`,
      [tenantId, username, since],
    );
  }

  /** Recent sales for the activity feed: only the fields the dashboard needs,
   *  with a LIMIT clause in SQL so large tenants don't load receipt blobs. */
  async getRecentSales(
    tenantId: string,
    limit: number,
  ): Promise<{ id: string; total_piastres: number; created_at: number }[]> {
    const res = await this.exec(
      `SELECT id, total_piastres, created_at FROM sales WHERE tenant_id = ? ORDER BY created_at DESC LIMIT ?`,
      [tenantId, limit],
    );
    return res.rows.map((row) => {
      const r = row as unknown as Record<string, unknown>;
      return {
        id: String(r['id']),
        total_piastres: Number(r['total_piastres'] ?? 0),
        created_at: Number(r['created_at'] ?? 0),
      };
    });
  }

  /** Checks schema health for the /health endpoint. Returns true when all
   *  expected tables exist and have the expected columns. */
  async checkSchema(): Promise<{
    auth_users: boolean;
    sessions_source: boolean;
    users_last_owner_login_at: boolean;
  }> {
    const res = await this.exec(`SELECT name FROM sqlite_master WHERE type='table' AND name IN ('auth_users','sessions','users')`);
    const tableNames = new Set(res.rows.map((r) => String((r as Record<string, unknown>)['name'])));
    const authUsers = tableNames.has('auth_users');
    const sessions = tableNames.has('sessions');
    const users = tableNames.has('users');

    let usersLastOwnerLoginAt = false;
    if (users) {
      const cols = await this.exec(`PRAGMA table_info(users)`);
      usersLastOwnerLoginAt = cols.rows.some(
        (r) => String((r as Record<string, unknown>)['name']) === 'last_owner_login_at',
      );
    }
    return {
      auth_users: authUsers,
      sessions_source: sessions,
      users_last_owner_login_at: usersLastOwnerLoginAt,
    };
  }
}
