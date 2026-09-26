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

export function createTurso(url: string, authToken: string): TursoDb {
  const client: Client = createClient({ url, authToken });
  return new TursoDb(client);
}

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

  // ---- sessions ----

  async insertSession(session: SessionRecord): Promise<void> {
    await this.exec(
      `INSERT INTO sessions (id, tenant_id, device_hwid, username, started_at, heartbeat_at, source)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
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
  }

  async heartbeatSession(sessionId: string, at: number): Promise<void> {
    await this.exec(`UPDATE sessions SET heartbeat_at = ? WHERE id = ?`, [at, sessionId]);
  }

  async endSession(sessionId: string, at: number): Promise<void> {
    await this.exec(`UPDATE sessions SET ended_at = ? WHERE id = ? AND ended_at IS NULL`, [at, sessionId]);
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

  private toSession(row: unknown): SessionRecord {
    const r = row as unknown as Record<string, unknown>;
    return {
      id: String(r['id']),
      tenant_id: String(r['tenant_id']),
      device_hwid: String(r['device_hwid']),
      username: String(r['username'] ?? ''),
      started_at: Number(r['started_at'] ?? 0),
      heartbeat_at: Number(r['heartbeat_at'] ?? 0),
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

  /** Records a failed login: bumps the counter and (from the 3rd failure)
   *  sets the exponential lockout. Pass null to bump without locking. */
  async recordAuthFailure(
    tenantId: string,
    username: string,
    lockedUntil: number | null,
  ): Promise<void> {
    await this.exec(
      `UPDATE auth_users SET failed_attempts = failed_attempts + 1, locked_until = ?, updated_at = ? WHERE tenant_id = ? AND username = ?`,
      [lockedUntil, Date.now(), tenantId, username],
    );
  }

  async resetAuthFailures(tenantId: string, username: string): Promise<void> {
    await this.exec(
      `UPDATE auth_users SET failed_attempts = 0, locked_until = NULL, updated_at = ? WHERE tenant_id = ? AND username = ?`,
      [Date.now(), tenantId, username],
    );
  }
}
