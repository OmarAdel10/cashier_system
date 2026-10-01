import { beforeEach, describe, expect, it, vi } from 'vitest';

// Mock @libsql/client at the lowest level — the api worker reaches Turso
// exclusively through backend/shared turso.ts.
const executeMock = vi.fn();
vi.mock('@libsql/client', () => ({
  createClient: vi.fn(() => ({ execute: executeMock })),
}));

import { createApp } from '../src/index';
import type { Env, Vars } from '../src/env';
import { mintSessionJwt, verifySessionJwt } from '../../shared/src/session_jwt';
import { hashTagged, verifyTagged } from '../../shared/src/password_kdf';
import { requireOwner, type VerifyTokenFn } from '../src/middleware/auth';
import { bytesToB64url } from '../../shared/src/base64';
import { createTurso } from '../../shared/src/turso';

/** Stub token verifier (real JWT crypto is covered in shared/jwt.test.ts). */
type StubVerifyResult = ReturnType<VerifyTokenFn>;
const verifyTokenStub = vi.fn((token: string): StubVerifyResult => {
  if (token === 'valid-uid-123')
    return Promise.resolve({
      valid: true,
      uid: 'uid-123',
      email: 'owner@daftari.co',
      signInProvider: 'google.com',
      emailVerified: true,
    });
  if (token === 'cashier-token')
    return Promise.resolve({
      valid: true,
      uid: 'uid-cashier',
      email: 'c@d.co',
      signInProvider: 'google.com',
      emailVerified: true,
    });
  return Promise.resolve({ valid: false });
});

// Mutable per-test DB state driven by the mocked execute().
interface DbState {
  userRows: Array<Record<string, unknown>>;
  sessionRows: Array<Record<string, unknown>>;
  saleRows: Array<Record<string, unknown>>;
  licenseRows: Array<Record<string, unknown>>;
  authUserRows: Array<Record<string, unknown>>;
  authAttemptRows: Array<Record<string, unknown>>;
  deviceRows: Array<Record<string, unknown>>;
}
const dbState: DbState = {
  userRows: [],
  sessionRows: [],
  saleRows: [],
  licenseRows: [],
  authUserRows: [],
  authAttemptRows: [],
  deviceRows: [],
};

const realtimeFetch = vi.fn(
  (_input: RequestInfo | URL, _init?: RequestInit) =>
    Promise.resolve(new Response(null, { status: 200 })),
);
const INTERNAL_NOTIFY_SECRET = 'test-internal-secret';
const logosPut = vi.fn(() => Promise.resolve());
const logosGet = vi.fn(() => Promise.resolve(null as unknown));

const env = {
  PAYMOB_HMAC_SECRET: 'hmac',
  ED25519_PRIVATE_KEY: 'priv',
  ED25519_PUBLIC_KEY: 'pub',
  FIREBASE_PROJECT_ID: 'daftari-pos',
  TURSO_DATABASE_URL: 'https://test.turso.io',
  TURSO_AUTH_TOKEN: 'turso-token',
  POSTHOG_API_KEY: 'phc_test',
  ADMIN_JWT_SECRET: 'test-admin-jwt-secret',
  INTERNAL_NOTIFY_SECRET,
  REALTIME: { fetch: realtimeFetch },
  LOGOS: { put: logosPut, get: logosGet },
};

/** Decode the JSON body the api sent to the realtime service binding. */
function realtimeBodies(): Array<Record<string, unknown>> {
  return realtimeFetch.mock.calls.map((call) => {
    const init = call[1];
    return JSON.parse(String(init?.body ?? '{}')) as Record<string, unknown>;
  });
}

function makeApp() {
  return createApp({ verifyToken: verifyTokenStub, postHogFetch: () => Promise.resolve(new Response('{"status":"Ok"}', { status: 200 })) });
}

function authHeaders(token = 'valid-uid-123') {
  return { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
}

/** Seeds a session row exactly as POST /auth/login would: a live web row for
 *  (tenant, jti). The auth gate (T10) reads it on every HS256 request, so
 *  every helper that mints a session JWT seeds a matching row. */
function seedSessionRow(overrides: Record<string, unknown> = {}): void {
  const now = Date.now();
  dbState.sessionRows.push({
    id: 'sess-api-1',
    tenant_id: 'uid-123',
    device_hwid: 'web',
    username: 'admin',
    started_at: now,
    heartbeat_at: now,
    ended_at: null,
    source: 'web',
    ...overrides,
  });
}

beforeEach(() => {
  vi.clearAllMocks();
  dbState.userRows = [{ tenant_id: 'uid-123', email: 'owner@daftari.co', role: 'admin', tier: 'starter', created_at: 1, last_login_at: 2, last_owner_login_at: Date.now() }];
  dbState.sessionRows = [];
  dbState.saleRows = [];
  dbState.licenseRows = [{ tenant_id: 'uid-123', device_hwid: 'hw1', license_key: 'k', subscription_end: 9, billing_cycle: 'monthly', grace_end: 9, status: 'active', created_at: 1 }];
  dbState.authUserRows = [];
  dbState.authAttemptRows = [];

  executeMock.mockImplementation(({ sql, args }: { sql: string; args?: unknown[] }) => {
    // Login throttling log (T17): append admitted attempts and answer the two
    // sliding-window counters from dbState.
    if (sql.includes('INSERT INTO auth_attempts')) {
      const [ip, tenantId, username, at] = (args ?? []) as [string, string, string, number];
      dbState.authAttemptRows.push({
        ip, tenant_id: tenantId, username, attempted_at: at,
      });
      return Promise.resolve({ rows: [], columns: [], rowsAffected: 1 });
    }
    if (sql.includes('FROM auth_attempts')) {
      const a = (args ?? []) as unknown[];
      let since: unknown;
      let rows = dbState.authAttemptRows.slice();
      if (sql.includes('ip = ?')) {
        rows = rows.filter((r) => r['ip'] === a[0]);
        since = a[1];
      } else {
        rows = rows.filter((r) => r['tenant_id'] === a[0] && r['username'] === a[1]);
        since = a[2];
      }
      const inWindow = rows.filter((r) => Number(r['attempted_at']) > Number(since));
      const oldest = inWindow.length
        ? Math.min(...inWindow.map((r) => Number(r['attempted_at'])))
        : null;
      return Promise.resolve({
        rows: [{ n: inWindow.length, oldest }], columns: [], rowsAffected: 0,
      });
    }
    // Single-row session lookup by primary key (auth-gate liveness, T10):
    // getLiveWebSession adds `ended_at IS NULL`; a missing or ended row is a
    // revoked session. Heartbeat freshness does not gate web sessions.
    if (sql.includes('FROM sessions') && sql.includes('WHERE id = ?')) {
      const [sessionId, tenant] = (args ?? []) as [string, string];
      let rows = dbState.sessionRows.filter(
        (s) => s['id'] === sessionId && s['tenant_id'] === tenant,
      );
      if (sql.includes('ended_at IS NULL')) rows = rows.filter((s) => s['ended_at'] == null);
      if (sql.includes('heartbeat_at > ?')) {
        const since = Number((args ?? [])[2]);
        rows = rows.filter((s) => Number(s['heartbeat_at']) > since);
      }
      return Promise.resolve({ rows, columns: [], rowsAffected: 0 });
    }
    // UPDATE sessions ... SET heartbeat_at (heartbeatSession, T13): tenant is
    // part of the predicate, so a foreign session id must affect 0 rows.
    if (sql.includes('UPDATE sessions') && sql.includes('heartbeat_at = ?')) {
      const [at, sessionId, tenant] = (args ?? []) as [number, string, string];
      let affected = 0;
      for (const s of dbState.sessionRows) {
        if (s['id'] === sessionId && s['tenant_id'] === tenant && s['ended_at'] == null) {
          s['heartbeat_at'] = at;
          affected += 1;
        }
      }
      return Promise.resolve({ rows: [], columns: [], rowsAffected: affected });
    }
    // UPDATE sessions ... SET ended_at (endSession / endSessionForTenant /
    // endWebSessions): mutate dbState so logout + revocation + IDOR tests can
    // prove the row actually died (and that a foreign row did not).
    if (sql.includes('UPDATE sessions') && sql.includes('ended_at = ?')) {
      const at = Number((args ?? [])[0]);
      let affected = 0;
      if (sql.includes('WHERE id = ?') && sql.includes('tenant_id = ?')) {
        const [, sessionId, tenant] = (args ?? []) as [number, string, string];
        for (const s of dbState.sessionRows) {
          if (s['id'] === sessionId && s['tenant_id'] === tenant && s['ended_at'] == null) {
            s['ended_at'] = at;
            affected += 1;
          }
        }
      } else if (sql.includes('username = ?')) {
        const [, tenant, username] = (args ?? []) as [number, string, string];
        for (const s of dbState.sessionRows) {
          if (s['tenant_id'] === tenant && s['username'] === username && s['ended_at'] == null) {
            s['ended_at'] = at;
            affected += 1;
          }
        }
      } else {
        const [, sessionId] = (args ?? []) as [number, string];
        for (const s of dbState.sessionRows) {
          if (s['id'] === sessionId && s['ended_at'] == null) {
            s['ended_at'] = at;
            affected += 1;
          }
        }
      }
      return Promise.resolve({ rows: [], columns: [], rowsAffected: affected });
    }
    if (sql.includes('UPDATE sessions') && sql.includes("device_hwid = ?") && sql.includes("source = 'pos'") && sql.includes('ended_at IS NULL')) {
      const [at, tenant, hwid] = (args ?? []) as [number, string, string];
      let affected = 0;
      for (const s of dbState.sessionRows) {
        if (s['tenant_id'] === tenant && s['device_hwid'] === hwid && s['source'] === 'pos' && s['ended_at'] == null) {
          s['ended_at'] = at;
          affected += 1;
        }
      }
      return Promise.resolve({ rows: [], columns: [], rowsAffected: affected });
    }
    // INSERT INTO sessions. The mock honours the two T12 invariants the SQL
    // relies on so a unit test can observe the rowsAffected contract (a mocked
    // client cannot exhibit true concurrency):
    //   POS: single-statement conditional INSERT ... SELECT WHERE (reconnect OR
    //        active POS count < limit).
    //   web: partial unique index idx_sessions_live_web + ON CONFLICT DO NOTHING.
    if (sql.includes('INSERT INTO sessions')) {
      const a = (args ?? []) as Array<string | number>;
      if (sql.includes('WHERE EXISTS')) {
        const [id, tenant, hwid, username, started, heartbeat] = a as [
          string, string, string, string, number, number,
        ];
        const limit = Number(a[9]);
        const posRows = dbState.sessionRows.filter(
          (s) => s['tenant_id'] === tenant && s['ended_at'] == null && s['source'] !== 'web',
        );
        const reconnect = posRows.some((s) => s['device_hwid'] === hwid);
        if (!reconnect && posRows.length >= limit) {
          return Promise.resolve({ rows: [], columns: [], rowsAffected: 0 });
        }
        dbState.sessionRows.push({
          id, tenant_id: tenant, device_hwid: hwid, username,
          started_at: started, heartbeat_at: heartbeat, ended_at: null, source: 'pos',
        });
        return Promise.resolve({ rows: [], columns: [], rowsAffected: 1 });
      }
      const [id, tenant, hwid, username, started, heartbeat, source] = a as [
        string, string, string, string, number, number, string,
      ];
      const conflict =
        source === 'web' &&
        dbState.sessionRows.some(
          (s) =>
            s['tenant_id'] === tenant &&
            s['username'] === username &&
            s['source'] === 'web' &&
            s['ended_at'] == null,
        );
      if (conflict) return Promise.resolve({ rows: [], columns: [], rowsAffected: 0 });
      dbState.sessionRows.push({
        id, tenant_id: tenant, device_hwid: hwid, username,
        started_at: started, heartbeat_at: heartbeat, ended_at: null, source,
      });
      return Promise.resolve({ rows: [], columns: [], rowsAffected: 1 });
    }
    // Per-username active-session query (login conflict check, T06):
    // simulate the heartbeat + username + tenant filters.
    if (sql.includes('heartbeat_at > ?') && sql.includes('username = ?')) {
      const [tenant, username, since] = (args ?? []) as [string, string, number];
      const rows = dbState.sessionRows.filter(
        (s) =>
          s['ended_at'] == null &&
          s['tenant_id'] === tenant &&
          s['username'] === username &&
          Number(s['heartbeat_at']) > Number(since),
      );
      return Promise.resolve({ rows, columns: [], rowsAffected: 0 });
    }
    // POS device-limit count (T06 QA F1): exclude web rows like the SQL does.
    if (sql.includes('heartbeat_at > ?') && sql.includes("source != 'web'") && !sql.includes('username = ?')) {
      const now = Date.now();
      const rows = dbState.sessionRows.filter(
        (s) => s['ended_at'] == null && s['source'] !== 'web' && Number(s['heartbeat_at']) > now - 5 * 60 * 1000,
      );
      return Promise.resolve({ rows, columns: [], rowsAffected: 0 });
    }
    if (sql.includes('FROM auth_users')) return Promise.resolve({ rows: dbState.authUserRows, columns: [], rowsAffected: 0 });
    if (sql.includes('FROM users')) return Promise.resolve({ rows: dbState.userRows, columns: [], rowsAffected: 0 });
    if (sql.includes('FROM sessions')) return Promise.resolve({ rows: dbState.sessionRows.filter((s) => s['ended_at'] == null), columns: [], rowsAffected: 0 });
    if (sql.includes('FROM sales')) return Promise.resolve({ rows: dbState.saleRows, columns: [], rowsAffected: 0 });
    if (sql.includes('FROM licenses')) return Promise.resolve({ rows: dbState.licenseRows, columns: [], rowsAffected: 0 });
    if (sql.includes('FROM devices')) return Promise.resolve({ rows: dbState.deviceRows, columns: [], rowsAffected: 0 });
    return Promise.resolve({ rows: [], columns: [], rowsAffected: 1 });
  });
});

describe('auth routes', () => {
  it('POST /auth/sync-user rejects missing bearer token → 401', async () => {
    const app = makeApp();
    const res = await app.request('/auth/sync-user', { method: 'POST' }, env);
    expect(res.status).toBe(401);
  });

  it('POST /auth/sync-user rejects invalid token → 401', async () => {
    const app = makeApp();
    const res = await app.request('/auth/sync-user', { method: 'POST', headers: authHeaders('bad-token') }, env);
    expect(res.status).toBe(401);
  });

  it('POST /auth/sync-user lazy-syncs a new user (Option B) and returns profile+license', async () => {
    dbState.userRows = []; // user not yet in Turso
    const app = makeApp();
    const res = await app.request('/auth/sync-user', { method: 'POST', headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { profile: { tenant_id: string }; license: unknown } };
    expect(body.ok).toBe(true);
    expect(body.data.profile.tenant_id).toBe('uid-123');
    // Lazy sync created the user row.
    const upsertCalls = executeMock.mock.calls.filter((c) => (c[0] as { sql: string }).sql.includes('INSERT INTO users'));
    expect(upsertCalls.length).toBeGreaterThanOrEqual(1);
  });

  it('POST /auth/sync-user is idempotent (second call does not duplicate the user)', async () => {
    const app = makeApp();
    await makeApp().request('/auth/sync-user', { method: 'POST', headers: authHeaders() }, env);
    executeMock.mockClear();
    const res = await app.request('/auth/sync-user', { method: 'POST', headers: authHeaders() }, env);
    expect(res.status).toBe(200);
  });

  it('GET /auth/me returns profile with role', async () => {
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { profile: { role: string } } };
    expect(body.data.profile.role).toBe('admin');
  });
});

describe('sessions routes', () => {
  it('POST /sessions/start creates a session (1st device on starter)', async () => {
    const app = makeApp();
    const res = await app.request('/sessions/start', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ device_hwid: 'hw1', device_name: 'Shop PC', platform: 'windows', username: 'admin' }),
    }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { session_id: string } };
    expect(body.ok).toBe(true);
    expect(typeof body.data.session_id).toBe('string');
  });

  it('POST /sessions/start rejects 2nd device on starter tier (limit 1) → 409', async () => {
    const now = Date.now();
    dbState.sessionRows = [{ id: 's1', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'admin', started_at: now - 1000, heartbeat_at: 9999999999999, source: 'pos' }];
    const app = makeApp();
    const res = await app.request('/sessions/start', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ device_hwid: 'hw2', device_name: 'Laptop', platform: 'linux' }),
    }, env);
    expect(res.status).toBe(409);
    const body = (await res.json()) as { ok: boolean; error: string; active_sessions: unknown[] };
    expect(body.ok).toBe(false);
    expect(body.active_sessions).toHaveLength(1);
  });

  it('POST /sessions/start allows 2nd device on pro tier (limit 2)', async () => {
    dbState.userRows = [{ tenant_id: 'uid-123', email: 'o@d.co', role: 'admin', tier: 'pro', created_at: 1 }];
    dbState.sessionRows = [{ id: 's1', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'admin', started_at: 1, heartbeat_at: 2 }];
    const app = makeApp();
    const res = await app.request('/sessions/start', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ device_hwid: 'hw2' }),
    }, env);
    expect(res.status).toBe(200);
  });

  it('POST /sessions/heartbeat updates heartbeat_at', async () => {
    seedSessionRow({ id: 's1', device_hwid: 'hw1', source: 'pos' });
    const app = makeApp();
    const res = await app.request('/sessions/heartbeat', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ session_id: 's1' }),
    }, env);
    expect(res.status).toBe(200);
    const calls = executeMock.mock.calls.filter((c) => (c[0] as { sql: string }).sql.includes('UPDATE sessions SET heartbeat_at'));
    expect(calls.length).toBe(1);
    // T13: the update is tenant-scoped at the SQL level.
    expect((calls[0]![0] as { sql: string }).sql).toContain('tenant_id = ?');
  });

  it('POST /sessions/end closes the session', async () => {
    seedSessionRow({ id: 's1', device_hwid: 'hw1', source: 'pos' });
    const app = makeApp();
    const res = await app.request('/sessions/end', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ session_id: 's1' }),
    }, env);
    expect(res.status).toBe(200);
    const calls = executeMock.mock.calls.filter((c) => (c[0] as { sql: string }).sql.includes('ended_at = ?'));
    expect(calls.length).toBe(1);
    expect((calls[0]![0] as { sql: string }).sql).toContain('tenant_id = ?');
  });

  it('POST /sessions/heartbeat does not touch another tenant session → 404 (T13 IDOR)', async () => {
    dbState.sessionRows = [
      { id: 'foreign', tenant_id: 'tenant-999', device_hwid: 'hw1', username: 'admin', started_at: 1, heartbeat_at: 111, ended_at: null, source: 'pos' },
    ];
    const app = makeApp();
    const res = await app.request('/sessions/heartbeat', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ session_id: 'foreign' }),
    }, env);
    expect(res.status).toBe(404);
    expect(((await res.json()) as { error: string }).error).toBe('SESSION_NOT_FOUND');
    expect(dbState.sessionRows[0]!['heartbeat_at']).toBe(111);
  });

  it('POST /sessions/end does not touch another tenant session → 404 (T13 IDOR)', async () => {
    dbState.sessionRows = [
      { id: 'foreign', tenant_id: 'tenant-999', device_hwid: 'hw1', username: 'admin', started_at: 1, heartbeat_at: 111, ended_at: null, source: 'pos' },
    ];
    const app = makeApp();
    const res = await app.request('/sessions/end', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ session_id: 'foreign' }),
    }, env);
    expect(res.status).toBe(404);
    expect(((await res.json()) as { error: string }).error).toBe('SESSION_NOT_FOUND');
    expect(dbState.sessionRows[0]!['ended_at']).toBeNull();
  });

  it('POST /sessions/end of a ghost session id → 404 SESSION_NOT_FOUND', async () => {
    const app = makeApp();
    const res = await app.request('/sessions/end', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ session_id: 'does-not-exist' }),
    }, env);
    expect(res.status).toBe(404);
  });

  it('GET /sessions/active lists open sessions only', async () => {
    dbState.sessionRows = [
      { id: 's1', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'a', started_at: 1, heartbeat_at: 1 },
    ];
    const app = makeApp();
    const res = await app.request('/sessions/active', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { sessions: unknown[] } };
    expect(body.data.sessions).toHaveLength(1);
  });
});

describe('sales routes', () => {
  it('POST /sales/sync posts a sale to the realtime service binding with the secret header', async () => {
    const app = makeApp();
    const res = await app.request('/sales/sync', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        sales: [
          { id: 'r1', receipt_json: '{}', total_piastres: 500, created_at: 10 },
          { id: 'r2', receipt_json: '{}', total_piastres: 300, created_at: 11 },
        ],
      }),
    }, env);
    expect(res.status).toBe(200);
    const calls = executeMock.mock.calls.filter((c) => (c[0] as { sql: string }).sql.includes('INSERT OR REPLACE INTO sales'));
    expect(calls.length).toBe(2);
    expect(realtimeFetch).toHaveBeenCalledTimes(1);
    expect(realtimeFetch).toHaveBeenCalledWith(
      'https://realtime/internal/notify',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({ 'X-Internal-Secret': INTERNAL_NOTIFY_SECRET }),
      }),
    );
    expect(realtimeBodies()[0]).toEqual({ tenantId: 'uid-123', event: 'sale', data: { count: 2 } });
  });

  it('the sale broadcast never contains receipt_json', async () => {
    const app = makeApp();
    const res = await app.request('/sales/sync', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        sales: [{ id: 'r1', receipt_json: '{"secret":"customer"}', total_piastres: 500, created_at: 10 }],
      }),
    }, env);
    expect(res.status).toBe(200);
    const body = realtimeBodies()[0] ?? {};
    expect(body).not.toHaveProperty('sales');
    expect(body).toEqual({ tenantId: 'uid-123', event: 'sale', data: { count: 1 } });
    expect(JSON.stringify(body)).not.toContain('receipt_json');
    expect(JSON.stringify(body)).not.toContain('customer');
  });

  it('GET /sales?since=100 returns rows', async () => {
    dbState.saleRows = [{ id: 'r1', tenant_id: 'uid-123', receipt_json: '{}', total_piastres: 500, created_at: 150 }];
    const app = makeApp();
    const res = await app.request('/sales?since=100', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { sales: unknown[] } };
    expect(body.data.sales).toHaveLength(1);
  });

  it('GET /sales?since=NaN returns 400 INVALID_FIELDS', async () => {
    const app = makeApp();
    const res = await app.request('/sales?since=abc', { headers: authHeaders() }, env);
    expect(res.status).toBe(400);
    expect(((await res.json()) as { error: string }).error).toBe('INVALID_FIELDS');
  });

  it('GET /sales?since=-1 returns 400 INVALID_FIELDS', async () => {
    const app = makeApp();
    const res = await app.request('/sales?since=-1', { headers: authHeaders() }, env);
    expect(res.status).toBe(400);
    expect(((await res.json()) as { error: string }).error).toBe('INVALID_FIELDS');
  });

  it('GET /sales?since=99999999999999999999 returns 400 INVALID_FIELDS', async () => {
    const app = makeApp();
    const res = await app.request('/sales?since=99999999999999999999', { headers: authHeaders() }, env);
    expect(res.status).toBe(400);
    expect(((await res.json()) as { error: string }).error).toBe('INVALID_FIELDS');
  });

  it('a malformed JSON body returns 400 INVALID_JSON not 500', async () => {
    const app = makeApp();
    const res = await app.request('/sales/sync', {
      method: 'POST',
      headers: authHeaders(),
      body: '{ invalid json }',
    }, env);
    expect(res.status).toBe(400);
    expect(((await res.json()) as { error: string }).error).toBe('INVALID_JSON');
  });
});

describe('admin routes', () => {
  const nowS = () => Math.floor(Date.now() / 1000);
  it('GET /admin/overview allows admin role → 200', async () => {
    const app = makeApp();
    const res = await app.request('/admin/overview', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
  });

  it('GET /admin/overview rejects cashier role → 403', async () => {
    dbState.userRows = [{ tenant_id: 'uid-cashier', email: 'c@d.co', role: 'cashier', tier: 'starter', created_at: 1 }];
    const app = makeApp();
    const res = await app.request('/admin/overview', { headers: authHeaders('cashier-token') }, env);
    expect(res.status).toBe(403);
  });

  it('GET /admin/overview rejects cashier session token → 403 DASHBOARD_ADMIN_ONLY', async () => {
    const { mintSessionJwt: mint } = await import('../../shared/src/session_jwt');
    const token = await mint({ tid: 'uid-123', usr: 'cashier1', role: 'cashier', jti: 'sess-cashier', iat: nowS(), exp: nowS() + 3600 }, 'test-admin-jwt-secret');
    seedSessionRow({ id: 'sess-cashier', username: 'cashier1', device_hwid: 'hw1', source: 'pos' });
    dbState.authUserRows = [{ tenant_id: 'uid-123', username: 'cashier1', role: 'cashier', is_active: 1, password_hash: 'x' }];
    const app = makeApp();
    const res = await app.request('/admin/overview', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: string }).error).toBe('DASHBOARD_ADMIN_ONLY');
  });

  it('GET /admin/overview accepts admin session token → 200', async () => {
    const { mintSessionJwt: mint } = await import('../../shared/src/session_jwt');
    const token = await mint({ tid: 'uid-123', usr: 'admin1', role: 'admin', jti: 'sess-admin', iat: nowS(), exp: nowS() + 3600 }, 'test-admin-jwt-secret');
    seedSessionRow({ id: 'sess-admin', username: 'admin1', device_hwid: 'hw1', source: 'pos' });
    dbState.authUserRows = [{ tenant_id: 'uid-123', username: 'admin1', role: 'admin', is_active: 1, password_hash: 'x' }];
    const app = makeApp();
    const res = await app.request('/admin/overview', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(200);
  });

  it('GET /admin/users rejects cashier session token → 403 DASHBOARD_ADMIN_ONLY', async () => {
    const { mintSessionJwt: mint } = await import('../../shared/src/session_jwt');
    const token = await mint({ tid: 'uid-123', usr: 'cashier2', role: 'cashier', jti: 'sess-cashier2', iat: nowS(), exp: nowS() + 3600 }, 'test-admin-jwt-secret');
    seedSessionRow({ id: 'sess-cashier2', username: 'cashier2', device_hwid: 'hw1', source: 'pos' });
    dbState.authUserRows = [{ tenant_id: 'uid-123', username: 'cashier2', role: 'cashier', is_active: 1, password_hash: 'x' }];
    const app = makeApp();
    const res = await app.request('/admin/users', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: string }).error).toBe('DASHBOARD_ADMIN_ONLY');
  });

  it('GET /admin/users accepts admin session token → 200', async () => {
    const { mintSessionJwt: mint } = await import('../../shared/src/session_jwt');
    const token = await mint({ tid: 'uid-123', usr: 'admin2', role: 'admin', jti: 'sess-admin2', iat: nowS(), exp: nowS() + 3600 }, 'test-admin-jwt-secret');
    seedSessionRow({ id: 'sess-admin2', username: 'admin2', device_hwid: 'hw1', source: 'pos' });
    dbState.authUserRows = [{ tenant_id: 'uid-123', username: 'admin2', role: 'admin', is_active: 1, password_hash: 'x' }];
    const app = makeApp();
    const res = await app.request('/admin/users', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(200);
  });

  it('POST /admin/users rejects cashier session token → 403 DASHBOARD_ADMIN_ONLY', async () => {
    const { mintSessionJwt: mint } = await import('../../shared/src/session_jwt');
    const token = await mint({ tid: 'uid-123', usr: 'cashier3', role: 'cashier', jti: 'sess-cashier3', iat: nowS(), exp: nowS() + 3600 }, 'test-admin-jwt-secret');
    seedSessionRow({ id: 'sess-cashier3', username: 'cashier3', device_hwid: 'hw1', source: 'pos' });
    dbState.authUserRows = [{ tenant_id: 'uid-123', username: 'cashier3', role: 'cashier', is_active: 1, password_hash: 'x' }];
    const app = makeApp();
    const res = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify({ username: 'newcashier', password: 'longenough12', role: 'cashier' }),
    }, env);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: string }).error).toBe('DASHBOARD_ADMIN_ONLY');
  });

  it('POST /admin/users accepts admin session token → 201', async () => {
    const { mintSessionJwt: mint } = await import('../../shared/src/session_jwt');
    const token = await mint({ tid: 'uid-123', usr: 'admin3', role: 'admin', jti: 'sess-admin3', iat: nowS(), exp: nowS() + 3600 }, 'test-admin-jwt-secret');
    seedSessionRow({ id: 'sess-admin3', username: 'admin3', device_hwid: 'hw1', source: 'pos' });
    dbState.authUserRows = [{ tenant_id: 'uid-123', username: 'admin3', role: 'admin', is_active: 1, password_hash: 'x' }];
    dbState.authUserRows = []; // clear for the insert
    const app = makeApp();
    const res = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify({ username: 'newcashier', password: 'longenough12', role: 'cashier' }),
    }, env);
    expect(res.status).toBe(201);
  });
});

describe('analytics routes', () => {
  it('POST /events accepts ≤50 events', async () => {
    const app = makeApp();
    const res = await app.request('/events', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ events: [{ event: 'sale_synced', properties: { tenant_id: 'uid-123' } }] }),
    }, env);
    expect(res.status).toBe(200);
  });

  it('POST /events rejects >50 events → 422', async () => {
    const app = makeApp();
    const events = Array.from({ length: 51 }, (_, i) => ({ event: `e${i}`, properties: {} }));
    const res = await app.request('/events', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ events }),
    }, env);
    expect(res.status).toBe(422);
  });
});

describe('branding routes', () => {
  it('POST /branding/logo accepts a clean SVG and puts it in R2', async () => {
    const app = makeApp();
    const svg = '<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>';
    const res = await app.request('/branding/logo', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ svg }),
    }, env);
    expect(res.status).toBe(200);
    expect(logosPut).toHaveBeenCalledWith('logos/uid-123.svg', svg, expect.objectContaining({ httpMetadata: expect.objectContaining({ contentType: 'image/svg+xml' }) }));
  });

  it('POST /branding/logo rejects SVG containing <script>', async () => {
    const app = makeApp();
    const svg = '<svg><script>alert(1)</script></svg>';
    const res = await app.request('/branding/logo', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ svg }),
    }, env);
    expect(res.status).toBe(422);
  });

  it('POST /branding/logo rejects SVG with event-handler attributes', async () => {
    const app = makeApp();
    const svg = '<svg onload="alert(1)"><rect/></svg>';
    const res = await app.request('/branding/logo', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ svg }),
    }, env);
    expect(res.status).toBe(422);
  });

  it('GET /branding/logo/:tenantId streams from R2', async () => {
    logosGet.mockResolvedValueOnce({ body: new ReadableStream() } as never);
    const app = makeApp();
    const res = await app.request('/branding/logo/uid-123', {}, env);
    expect(res.status).toBe(200);
  });

  it('GET /branding/logo/:tenantId returns 404 when missing', async () => {
    const app = makeApp();
    const res = await app.request('/branding/logo/unknown', {}, env);
    expect(res.status).toBe(404);
  });
});

describe('dual-token middleware (admin-dashboard T05)', () => {
  const SECRET = 'test-admin-jwt-secret';
  const nowS = () => Math.floor(Date.now() / 1000);

  async function mintSession(overrides: Record<string, unknown> = {}): Promise<string> {
    const claims = {
      tid: 'uid-123',
      usr: 'admin',
      role: 'admin',
      jti: 'sess-api-1',
      iat: nowS(),
      exp: nowS() + 3600,
      ...overrides,
    };
    // A minted token implies a live session row (T10 liveness gate).
    seedSessionRow({
      id: String(claims.jti),
      tenant_id: String(claims.tid),
      username: String(claims.usr),
    });
    return mintSessionJwt(claims as Parameters<typeof mintSessionJwt>[0], SECRET);
  }

  it('accepts a session-JWT (HS256) token on GET /auth/me', async () => {
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders(await mintSession()) }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { profile: { tenant_id: string } } };
    expect(body.ok).toBe(true);
    expect(body.data.profile.tenant_id).toBe('uid-123');
  });

  it('session path skips the lazy user upsert', async () => {
    dbState.userRows = [];
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders(await mintSession()) }, env);
    expect(res.status).toBe(200);
    const upsertCalls = executeMock.mock.calls.filter((c) =>
      (c[0] as { sql: string }).sql.includes('INSERT INTO users'),
    );
    expect(upsertCalls).toHaveLength(0);
  });

  it('rejects a session JWT signed with the wrong secret → 401', async () => {
    const token = await mintSessionJwt(
      { tid: 'uid-123', usr: 'admin', role: 'admin', jti: 'sess-api-wrong-secret', iat: nowS(), exp: nowS() + 3600 },
      'wrong-secret',
    );
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    // Structured code, not a message string: the web client routes its
    // session-expiry handling off this field (security review fix).
    expect(body.error).toBe('SESSION_EXPIRED');
  });

  it('rejects an expired session JWT → 401', async () => {
    const token = await mintSession({ exp: nowS() - 1 });
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe('SESSION_EXPIRED');
  });

  it('treats a leading-dot token as non-session → 401 Invalid token', async () => {
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders('.abc.def') }, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe('Invalid token');
  });

  it('rejects a Firebase token with a missing sign_in_provider → 401 PROVIDER_NOT_ALLOWED', async () => {
    verifyTokenStub.mockResolvedValueOnce({
      valid: true,
      uid: 'uid-123',
      email: 'o@d.co',
      emailVerified: true,
    });
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders('fb-token') }, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe('PROVIDER_NOT_ALLOWED');
  });

  it('rejects a Firebase token with an unlisted sign_in_provider → 401 PROVIDER_NOT_ALLOWED', async () => {
    verifyTokenStub.mockResolvedValueOnce({
      valid: true,
      uid: 'uid-123',
      email: 'o@d.co',
      signInProvider: 'github.com',
      emailVerified: true,
    });
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders('fb-token') }, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe('PROVIDER_NOT_ALLOWED');
  });

  // T11: Firebase shares one provider id across the Email/Password family, so a
  // magic-link (email-link) token carries sign_in_provider 'password'. It must
  // pass the allowlist or every magic-link login 401s. Asserted directly on the
  // middleware so the result does not depend on the db mock's lazy-sync shape.
  it('accepts a password sign_in_provider as the magic-link path (T11)', async () => {
    const { requireAuth: makeRequireAuth } = await import('../src/middleware/auth');
    const middleware = makeRequireAuth({
      verifyToken: async () => ({
        valid: true,
        uid: 'uid-123',
        email: 'o@d.co',
        signInProvider: 'password',
        emailVerified: true,
      }),
      db: () => ({ getUser: async () => null, upsertUser: async () => undefined }) as never,
    });
    const next = vi.fn();
    const jsonFn = vi.fn(() => new Response(null, { status: 401 }));
    const res = await middleware(
      {
        req: { header: () => 'Bearer fb-token' },
        env: { FIREBASE_PROJECT_ID: 'proj', ADMIN_JWT_SECRET: 'secret' },
        get: () => undefined,
        set: () => undefined,
        json: jsonFn,
      } as never,
      next,
    );
    expect(jsonFn).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalled();
    expect(res).toBeUndefined();
  });

  it('rejects a Firebase token with an unverified email → 401 EMAIL_NOT_VERIFIED', async () => {
    verifyTokenStub.mockResolvedValueOnce({
      valid: true,
      uid: 'uid-123',
      email: 'o@d.co',
      signInProvider: 'google.com',
      emailVerified: false,
    });
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders('fb-token') }, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe('EMAIL_NOT_VERIFIED');
  });

  it('requireOwner blocks session tokens and allows Firebase owners', async () => {
    const middleware = requireOwner();
    const blockedJson = vi.fn(() => new Response(null, { status: 403 }));
    const blocked = await middleware(
      { get: () => false, json: blockedJson } as never,
      vi.fn(),
    );
    expect((blocked as Response).status).toBe(403);

    const next = vi.fn();
    const allowed = await middleware({ get: () => true, json: vi.fn() } as never, next);
    expect(allowed).toBeUndefined();
    expect(next).toHaveBeenCalled();
  });

  it('requireAuth→requireOwner integration: session blocked, Firebase owner allowed', async () => {
    // Pins the authIsOwner contract T06 builds on: false on the session
    // path, true on the Firebase path (T05 coverage round 1, Gap 1).
    const { Hono } = await import('hono');
    const { getDb } = await import('../src/db');
    const { requireAuth } = await import('../src/middleware/auth');
    const app = new Hono<{ Bindings: Env; Variables: Vars }>();
    app.use('*', requireAuth({ verifyToken: verifyTokenStub, db: getDb }));
    app.use('*', requireOwner());
    app.get('/owner-only', (c) => c.json({ ok: true, data: { uid: c.get('authUid') } }));

    const blocked = await app.request(
      '/owner-only',
      { headers: authHeaders(await mintSession()) },
      env,
    );
    expect(blocked.status).toBe(403);
    expect(((await blocked.json()) as { error: string }).error).toBe('OWNER_ONLY');

    const allowed = await app.request('/owner-only', { headers: authHeaders() }, env);
    expect(allowed.status).toBe(200);
    const body = (await allowed.json()) as { data: { uid: string } };
    expect(body.data.uid).toBe('uid-123');
  });
});

describe('session liveness + revocation + logout (bundle A3 / T10)', () => {
  const SECRET = 'test-admin-jwt-secret';
  const nowS = () => Math.floor(Date.now() / 1000);

  function sessionJwtFor(jti: string, tenantId = 'uid-123'): Promise<string> {
    return mintSessionJwt(
      { tid: tenantId, usr: 'admin', role: 'admin', jti, iat: nowS(), exp: nowS() + 3600 },
      SECRET,
    );
  }

  it('accepts a token whose jti names a live, fresh session row', async () => {
    seedSessionRow({ id: 'live-1' });
    const app = makeApp();
    const res = await app.request(
      '/auth/me',
      { headers: authHeaders(await sessionJwtFor('live-1')) },
      env,
    );
    expect(res.status).toBe(200);
  });

  it('rejects a session row that was already ended → 401 SESSION_REVOKED', async () => {
    seedSessionRow({ id: 'ended-1', ended_at: Date.now() });
    const app = makeApp();
    const res = await app.request(
      '/auth/me',
      { headers: authHeaders(await sessionJwtFor('ended-1')) },
      env,
    );
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: string }).error).toBe('SESSION_REVOKED');
  });

  it('rejects a token once its row is ended through POST /sessions/end → 401 SESSION_REVOKED', async () => {
    seedSessionRow({ id: 'end-via-route' });
    const token = await sessionJwtFor('end-via-route');
    const app = makeApp();
    const before = await app.request('/auth/me', { headers: authHeaders(token) }, env);
    expect(before.status).toBe(200);
    const ended = await app.request(
      '/sessions/end',
      {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ session_id: 'end-via-route' }),
      },
      env,
    );
    expect(ended.status).toBe(200);
    const res = await app.request('/auth/me', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: string }).error).toBe('SESSION_REVOKED');
  });

  it('rejects a token whose jti names no row → 401 SESSION_REVOKED', async () => {
    const app = makeApp();
    const res = await app.request(
      '/auth/me',
      { headers: authHeaders(await sessionJwtFor('ghost')) },
      env,
    );
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: string }).error).toBe('SESSION_REVOKED');
  });

  it('rejects a row owned by another tenant → 401 SESSION_REVOKED', async () => {
    seedSessionRow({ id: 'other-tenant-row', tenant_id: 'tenant-999' });
    const app = makeApp();
    const res = await app.request(
      '/auth/me',
      { headers: authHeaders(await sessionJwtFor('other-tenant-row')) },
      env,
    );
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: string }).error).toBe('SESSION_REVOKED');
  });

  it('accepts a web session whose heartbeat is 6 hours old (no heartbeat required)', async () => {
    seedSessionRow({ id: 'web-old-heartbeat', heartbeat_at: Date.now() - 6 * 60 * 60 * 1000 });
    const app = makeApp();
    const res = await app.request(
      '/auth/me',
      { headers: authHeaders(await sessionJwtFor('web-old-heartbeat')) },
      env,
    );
    expect(res.status).toBe(200);
  });

  // SECURITY REGRESSION (backend auth checkpoint review, Critical #2).
  // Deactivating an admin sets auth_users.is_active = 0 but ends NO session
  // row, and the gate previously consulted only the sessions table — so a
  // deactivated (or downgraded) admin kept full access and could slide its 12h
  // token forward indefinitely by calling /auth/session/resume before each
  // expiry. The gate now re-reads the account row per request.
  it('rejects a session token whose account is deactivated → 401 SESSION_REVOKED', async () => {
    seedSessionRow({ id: 'deactivated-1' });
    dbState.authUserRows = [
      { tenant_id: 'uid-123', username: 'admin', role: 'admin', is_active: 0 },
    ];
    const app = makeApp();
    const res = await app.request(
      '/auth/me',
      { headers: authHeaders(await sessionJwtFor('deactivated-1')) },
      env,
    );
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: string }).error).toBe('SESSION_REVOKED');
  });

  it('POST /auth/logout ends the caller session and returns ok', async () => {
    seedSessionRow({ id: 'logout-1' });
    const token = await sessionJwtFor('logout-1');
    const app = makeApp();
    const res = await app.request(
      '/auth/logout',
      { method: 'POST', headers: authHeaders(token) },
      env,
    );
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
    expect(dbState.sessionRows.find((s) => s['id'] === 'logout-1')?.['ended_at']).toEqual(
      expect.any(Number),
    );
    const after = await app.request('/auth/me', { headers: authHeaders(token) }, env);
    expect(after.status).toBe(401);
    expect(((await after.json()) as { error: string }).error).toBe('SESSION_REVOKED');
  });

  it('POST /auth/logout is idempotent — a second call still returns ok', async () => {
    seedSessionRow({ id: 'logout-twice' });
    const token = await sessionJwtFor('logout-twice');
    const app = makeApp();
    const first = await app.request(
      '/auth/logout',
      { method: 'POST', headers: authHeaders(token) },
      env,
    );
    const second = await app.request(
      '/auth/logout',
      { method: 'POST', headers: authHeaders(token) },
      env,
    );
    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    expect(await second.json()).toEqual({ ok: true });
  });

  it('POST /auth/logout leaves the same tenant other session untouched', async () => {
    seedSessionRow({ id: 'mine-1' });
    seedSessionRow({ id: 'sibling-1' });
    const app = makeApp();
    const res = await app.request(
      '/auth/logout',
      {
        method: 'POST',
        headers: authHeaders(await sessionJwtFor('mine-1')),
        // A caller-supplied session_id must be ignored outright.
        body: JSON.stringify({ session_id: 'sibling-1' }),
      },
      env,
    );
    expect(res.status).toBe(200);
    expect(dbState.sessionRows.find((s) => s['id'] === 'mine-1')?.['ended_at']).toEqual(
      expect.any(Number),
    );
    expect(dbState.sessionRows.find((s) => s['id'] === 'sibling-1')?.['ended_at']).toBeNull();
  });

  it('POST /auth/logout never ends another tenant row that shares the jti', async () => {
    seedSessionRow({ id: 'dup-id' });
    seedSessionRow({ id: 'dup-id', tenant_id: 'tenant-999' });
    const app = makeApp();
    const res = await app.request(
      '/auth/logout',
      { method: 'POST', headers: authHeaders(await sessionJwtFor('dup-id')) },
      env,
    );
    expect(res.status).toBe(200);
    const mine = dbState.sessionRows.find(
      (s) => s['id'] === 'dup-id' && s['tenant_id'] === 'uid-123',
    );
    const theirs = dbState.sessionRows.find(
      (s) => s['id'] === 'dup-id' && s['tenant_id'] === 'tenant-999',
    );
    expect(mine?.['ended_at']).toEqual(expect.any(Number));
    expect(theirs?.['ended_at']).toBeNull();
  });

  it('POST /auth/logout rejects a request without a bearer token → 401', async () => {
    const app = makeApp();
    const res = await app.request('/auth/logout', { method: 'POST' }, env);
    expect(res.status).toBe(401);
  });

  it('POST /auth/logout rejects a Firebase token → 401', async () => {
    const app = makeApp();
    const res = await app.request('/auth/logout', { method: 'POST', headers: authHeaders() }, env);
    expect(res.status).toBe(401);
  });
});

describe('login + revoke routes (admin-dashboard T06)', () => {
  const SECRET = 'test-admin-jwt-secret';

  async function seedAuthUser(overrides: Record<string, unknown> = {}): Promise<void> {
    const stored = await hashTagged('secret1', 1000, 'c2FsdHNhbHQ');
    dbState.authUserRows = [
      {
        tenant_id: 'uid-123',
        username: 'admin',
        password_hash: stored,
        role: 'admin',
        display_name: null,
        must_change_password: 0,
        is_active: 1,
        failed_attempts: 0,
        locked_until: null,
        created_at: 1,
        updated_at: 1,
        ...overrides,
      },
    ];
  }

  const loginBody = { tenant_id: 'uid-123', username: 'admin', password: 'secret1' };

  it('POST /auth/login succeeds: minted session JWT + web session + failure reset', async () => {
    await seedAuthUser();
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      ok: boolean;
      data: { token: string; session_id: string; profile: { tenant_id: string } };
    };
    expect(body.ok).toBe(true);
    const claims = await verifySessionJwt(body.data.token, SECRET);
    expect(claims?.tid).toBe('uid-123');
    expect(claims?.usr).toBe('admin');
    expect(claims?.role).toBe('admin');
    expect(claims!.exp - claims!.iat).toBe(12 * 3600); // 12h TTL pinned
    expect(body.data.session_id).toBeTruthy();

    const insertSession = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('INSERT INTO sessions'),
    );
    expect(insertSession).toBeDefined();
    expect((insertSession![0] as { args: unknown[] }).args![6]).toBe('web');

    const reset = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('failed_attempts = 0'),
    );
    expect(reset).toBeDefined();
  });

  it('POST /auth/login rejects missing fields → 400', async () => {
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin' }),
    }, env);
    expect(res.status).toBe(400);
  });

  it('unknown username → 401 BAD_CREDENTIALS without recording failures', async () => {
    dbState.authUserRows = [];
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(401);
    const failure = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('failed_attempts + 1'),
    );
    expect(failure).toBeUndefined();
  });

  it('wrong password → 401 and failure recorded', async () => {
    await seedAuthUser();
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...loginBody, password: 'wrong' }),
    }, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe('BAD_CREDENTIALS');
    const failure = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('failed_attempts + 1'),
    );
    expect(failure).toBeDefined();
  });

  // T16 (DAFTARI-96): the KDF must run for EVERY login attempt, including an
  // unknown username, so response timing cannot enumerate accounts. The route
  // takes the verifier as a dependency precisely so this can be observed.
  it('an unknown username still performs a password derivation (T16)', async () => {
    dbState.authUserRows = [];
    const derive = vi.fn(() => Promise.resolve(false));
    const app = createApp({
      verifyToken: verifyTokenStub,
      verify: derive,
      postHogFetch: () => Promise.resolve(new Response('{"status":"Ok"}', { status: 200 })),
    });
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(401);
    expect(derive).toHaveBeenCalledTimes(1);
    // A real, valid-shaped dummy hash (not the empty string) so the cost is
    // the same derivation cost a real account pays.
    const [stored, password] = derive.mock.calls[0]! as unknown as [string, string];
    expect(stored).toMatch(/^pbkdf2-sha512\$10000\$/);
    expect(stored).not.toBe('');
    expect(password).toBe('secret1');
  });

  it('a known user derives against their stored hash exactly once (T16)', async () => {
    await seedAuthUser();
    const derive = vi.fn(() => Promise.resolve(true));
    const app = createApp({
      verifyToken: verifyTokenStub,
      verify: derive,
      postHogFetch: () => Promise.resolve(new Response('{"status":"Ok"}', { status: 200 })),
    });
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(200);
    expect(derive).toHaveBeenCalledTimes(1);
    const [stored] = derive.mock.calls[0]! as unknown as [string];
    expect(dbState.authUserRows[0]!['password_hash']).toBe(stored);
  });

  it('an expired lock resets failed_attempts so it cannot relock instantly (T16)', async () => {
    await seedAuthUser({ failed_attempts: 30, locked_until: Date.now() - 1000 });
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...loginBody, password: 'wrong' }),
    }, env);
    expect(res.status).toBe(401);
    const reset = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('failed_attempts = 0'),
    );
    expect(reset).toBeDefined();
    const failure = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('failed_attempts + 1'),
    );
    // Counter restarted: first failure after the lock window is not a lock.
    expect((failure![0] as { args: unknown[] }).args![0]).toBeNull();
  });

  // T17 (DAFTARI-97): the login surface is throttled before any derivation,
  // per IP and per (tenant, username), 10 attempts / 15 minutes.
  it('the 11th login attempt from one IP within 15 minutes → 429 RATE_LIMITED (T17)', async () => {
    await seedAuthUser();
    const now = Date.now();
    for (let i = 0; i < 10; i++) {
      dbState.authAttemptRows.push({
        ip: '9.9.9.9', tenant_id: 'uid-123', username: `user${i}`, attempted_at: now - i * 1000,
      });
    }
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': '9.9.9.9' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(429);
    const body = (await res.json()) as { error: string; retry_after_ms: number };
    expect(body.error).toBe('RATE_LIMITED');
    expect(body.retry_after_ms).toBeGreaterThan(0);
    // No derivation is paid and no failure is recorded for a throttled call.
    const failure = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('failed_attempts + 1'),
    );
    expect(failure).toBeUndefined();
  });

  it('a throttled login from a different IP is unaffected (T17)', async () => {
    await seedAuthUser();
    const now = Date.now();
    for (let i = 0; i < 10; i++) {
      dbState.authAttemptRows.push({
        ip: '9.9.9.9', tenant_id: 'uid-123', username: `user${i}`, attempted_at: now - i * 1000,
      });
    }
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': '8.8.8.8' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(200);
  });

  it('an admitted login records its attempt for the next window check (T17)', async () => {
    await seedAuthUser();
    const app = makeApp();
    await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': '7.7.7.7' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(dbState.authAttemptRows).toEqual([
      expect.objectContaining({ ip: '7.7.7.7', tenant_id: 'uid-123', username: 'admin' }),
    ]);
  });

  it('locked account → 429 LOGIN_LOCKED even with the correct password', async () => {
    await seedAuthUser({ failed_attempts: 3, locked_until: Date.now() + 60_000 });
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(429);
    const body = (await res.json()) as { error: string; locked_until: number };
    expect(body.error).toBe('LOGIN_LOCKED');
    expect(body.locked_until).toBeGreaterThan(Date.now());
  });

  it('expired lock → login succeeds again', async () => {
    await seedAuthUser({ failed_attempts: 3, locked_until: Date.now() - 1000 });
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(200);
  });

  it('deactivated account → 401 BAD_CREDENTIALS', async () => {
    await seedAuthUser({ is_active: 0 });
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(401);
  });

  it('cashier-role account → 403 DASHBOARD_ADMIN_ONLY', async () => {
    await seedAuthUser({ role: 'cashier' });
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(403);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe('DASHBOARD_ADMIN_ONLY');
  });

  it('stale owner login (>90 days) → 401 OWNER_REAUTH_REQUIRED', async () => {
    await seedAuthUser();
    dbState.userRows[0]!['last_owner_login_at'] = Date.now() - 91 * 24 * 3600 * 1000;
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe('OWNER_REAUTH_REQUIRED');
  });

  it('never-refreshed owner → 401 OWNER_REAUTH_REQUIRED', async () => {
    await seedAuthUser();
    dbState.userRows[0]!['last_owner_login_at'] = null;
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: string }).error).toBe('OWNER_REAUTH_REQUIRED');
  });

  // SECURITY REGRESSION (backend auth checkpoint review, Critical #1).
  // An earlier revision suppressed the 90-day owner gate whenever
  // getActiveSessionsForUsername(tenantId, username, 0) was non-empty. That
  // predicate is `ended_at IS NULL AND heartbeat_at > ?` with since = 0, i.e.
  // 'any unended row ever' — and a web row survives until an explicit logout
  // or the NEXT login. So one gated login, then never logging out (or logging
  // in every <12h), suppressed owner re-auth FOREVER. The gate is now
  // unconditional on /auth/login. The 'an active session must not be
  // interrupted' requirement is met by /auth/session/resume instead, which is
  // only reachable with a genuinely live session and never applies this gate.
  it('an unended session row does NOT bypass the owner gate (T11 security fix)', async () => {
    await seedAuthUser();
    dbState.userRows[0]!['last_owner_login_at'] = Date.now() - 91 * 24 * 3600 * 1000;
    dbState.sessionRows = [
      { id: 'live-web', tenant_id: 'uid-123', device_hwid: 'web', username: 'admin', started_at: 1, heartbeat_at: Date.now() - 6 * 60 * 60 * 1000, ended_at: null, source: 'web' },
    ];
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: string }).error).toBe('OWNER_REAUTH_REQUIRED');
  });

  it('an ended session row does not satisfy the owner gate (T11)', async () => {
    await seedAuthUser();
    dbState.userRows[0]!['last_owner_login_at'] = Date.now() - 91 * 24 * 3600 * 1000;
    dbState.sessionRows = [
      { id: 'ended-web', tenant_id: 'uid-123', device_hwid: 'web', username: 'admin', started_at: 1, heartbeat_at: 1, ended_at: Date.now(), source: 'web' },
    ];
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: string }).error).toBe('OWNER_REAUTH_REQUIRED');
  });

  it('maps a lost web-session admission race to 409 SESSION_CONFLICT (T12)', async () => {
    // The unique index makes the second, overlapping login's INSERT a no-op;
    // insertSession then reports false and the route must surface the conflict
    // rather than mint a token for a row that was never written.
    const stored = await hashTagged('secret1', 1000, 'c2FsdHNhbHQ');
    const fakeDb = {
      getAuthUser: async () => ({
        tenant_id: 'uid-123', username: 'admin', password_hash: stored, role: 'admin',
        display_name: null, must_change_password: 0, is_active: 1,
        failed_attempts: 0, locked_until: null, created_at: 1, updated_at: 1,
      }),
      getUser: async () => ({
        tenant_id: 'uid-123', email: 'owner@daftari.co', role: 'admin', tier: 'starter',
        created_at: 1, last_login_at: 2, last_owner_login_at: Date.now(),
      }),
      getActiveSessionsForUsername: async () => [],
      resetAuthFailures: async () => undefined,
      endWebSessions: async () => undefined,
      insertSession: async () => false,
      countAuthAttemptsByIp: async () => ({ count: 0, oldestAt: null }),
      countAuthAttemptsByAccount: async () => ({ count: 0, oldestAt: null }),
      recordAuthAttempt: async () => undefined,
    };
    const app = createApp({
      verifyToken: verifyTokenStub,
      getDb: () => fakeDb as never,
      postHogFetch: () => Promise.resolve(new Response('{"status":"Ok"}', { status: 200 })),
    });
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(409);
    expect(((await res.json()) as { error: string }).error).toBe('SESSION_CONFLICT');
  });

  it('active session for the username → 409 SESSION_CONFLICT with id', async () => {
    await seedAuthUser();
    dbState.sessionRows = [
      { id: 'sess-x', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'admin', started_at: 1, heartbeat_at: Date.now(), ended_at: null },
    ];
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(409);
    const body = (await res.json()) as { error: string; conflict_session_id: string };
    expect(body.error).toBe('SESSION_CONFLICT');
    expect(body.conflict_session_id).toBe('sess-x');
  });

  it('stale heartbeat (>5 min) does NOT block login (staleness rule)', async () => {
    await seedAuthUser();
    dbState.sessionRows = [
      { id: 'sess-stale', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'admin', started_at: 1, heartbeat_at: Date.now() - 6 * 60 * 1000, ended_at: null },
    ];
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(200);
  });

  it('POST /sessions/revoke ends the username sessions and notifies realtime', async () => {
    dbState.sessionRows = [
      { id: 's1', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'admin', started_at: 1, heartbeat_at: Date.now(), ended_at: null },
      { id: 's2', tenant_id: 'uid-123', device_hwid: 'web', username: 'admin', started_at: 2, heartbeat_at: Date.now(), ended_at: null },
      { id: 's3', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'other', started_at: 3, heartbeat_at: Date.now(), ended_at: null },
    ];
    const app = makeApp();
    const res = await app.request('/sessions/revoke', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ username: 'admin' }),
    }, env);
    expect(res.status).toBe(200);
    const endCalls = executeMock.mock.calls.filter((c) => {
      const sql = (c[0] as { sql: string }).sql;
      return sql.includes('UPDATE sessions') && sql.includes('ended_at = ?');
    });
    expect(endCalls).toHaveLength(2);
    expect(realtimeFetch).toHaveBeenCalledWith(
      'https://realtime/internal/notify',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({ 'X-Internal-Secret': INTERNAL_NOTIFY_SECRET }),
      }),
    );
    expect(realtimeBodies()[0]).toEqual({
      tenantId: 'uid-123',
      event: 'session_revoked',
      data: { username: 'admin', at: expect.any(Number) },
    });
  });

  it('POST /auth/owner-refresh stamps last_owner_login_at (Firebase owner)', async () => {
    const app = makeApp();
    const res = await app.request('/auth/owner-refresh', { method: 'POST', headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const touch = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('last_owner_login_at = ?'),
    );
    expect(touch).toBeDefined();
  });

  it('POST /auth/owner-refresh rejects session tokens → 403 OWNER_ONLY', async () => {
    const nowS = Math.floor(Date.now() / 1000);
    const token = await mintSessionJwt(
      { tid: 'uid-123', usr: 'admin', role: 'admin', jti: 'sess-owner-refresh', iat: nowS, exp: nowS + 3600 },
      SECRET,
    );
    seedSessionRow({ id: 'sess-owner-refresh' });
    const app = makeApp();
    const res = await app.request('/auth/owner-refresh', { method: 'POST', headers: authHeaders(token) }, env);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: string }).error).toBe('OWNER_ONLY');
  });

  it('3rd failure writes the exponential lock value (lockUntilFor pin)', async () => {
    await seedAuthUser({ failed_attempts: 2 }); // route computes lockUntilFor(3)
    const app = makeApp();
    const before = Date.now();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...loginBody, password: 'wrong' }),
    }, env);
    expect(res.status).toBe(401);
    const failure = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('failed_attempts + 1'),
    );
    expect(failure).toBeDefined();
    const lock = (failure![0] as { args: unknown[] }).args![0] as number | null;
    expect(lock).not.toBeNull();
    expect(lock!).toBeGreaterThanOrEqual(before + 2 ** 3 * 15_000);
    expect(lock!).toBeLessThanOrEqual(Date.now() + 2 ** 3 * 15_000);
  });

  it('lock value caps at 15 minutes regardless of attempt count', async () => {
    await seedAuthUser({ failed_attempts: 20 }); // 2^20 * 15s >> cap
    const app = makeApp();
    const before = Date.now();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...loginBody, password: 'wrong' }),
    }, env);
    expect(res.status).toBe(401);
    const failure = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('failed_attempts + 1'),
    );
    const lock = (failure![0] as { args: unknown[] }).args![0] as number;
    expect(lock).toBeGreaterThanOrEqual(before + 900_000);
    expect(lock).toBeLessThanOrEqual(Date.now() + 900_000);
  });

  it('login ends prior unended web sessions for the username (F1 hygiene)', async () => {
    await seedAuthUser();
    dbState.sessionRows = [
      { id: 'web-old', tenant_id: 'uid-123', device_hwid: 'web', username: 'admin', started_at: 1, heartbeat_at: 1, ended_at: null, source: 'web' },
    ];
    const app = makeApp();
    const res = await app.request('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginBody),
    }, env);
    expect(res.status).toBe(200);
    const endWeb = executeMock.mock.calls.find((c) => {
      const sql = (c[0] as { sql: string }).sql;
      return sql.includes('UPDATE sessions') && sql.includes("source = 'web'");
    });
    expect(endWeb).toBeDefined();
  });

  it('POST /sessions/start ignores web sessions in the device-limit count (F1)', async () => {
    await seedAuthUser();
    dbState.sessionRows = [
      { id: 'web-1', tenant_id: 'uid-123', device_hwid: 'web', username: 'admin', started_at: 1, heartbeat_at: 1, ended_at: null, source: 'web' },
    ];
    // Seeded user is starter tier (limit 1) — a counted web row would 409.
    const app = makeApp();
    const res = await app.request('/sessions/start', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ device_hwid: 'pos-new', device_name: 'Main', platform: 'linux' }),
    }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { session_id: string } };
    expect(body.data.session_id).toBeTruthy();
  });

  it('POST /sessions/revoke rejects missing username → 400', async () => {
    const app = makeApp();
    const res = await app.request('/sessions/revoke', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({}),
    }, env);
    expect(res.status).toBe(400);
    expect(((await res.json()) as { error: string }).error).toBe('MISSING_FIELDS');
  });

  it('POST /sessions/revoke with no active sessions → ended 0, no notify', async () => {
    dbState.sessionRows = [];
    const app = makeApp();
    const res = await app.request('/sessions/revoke', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ username: 'admin' }),
    }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { ended: number } };
    expect(body.data.ended).toBe(0);
    expect(realtimeFetch).not.toHaveBeenCalled();
  });

  it('POST /sessions/revoke ends only own-tenant sessions (token scoping)', async () => {
    dbState.sessionRows = [
      { id: 's-mine', tenant_id: 'uid-123', device_hwid: 'web', username: 'admin', started_at: 1, heartbeat_at: Date.now(), ended_at: null, source: 'web' },
      { id: 's-theirs', tenant_id: 'other-tenant', device_hwid: 'web', username: 'admin', started_at: 1, heartbeat_at: Date.now(), ended_at: null, source: 'web' },
    ];
    const app = makeApp();
    const res = await app.request('/sessions/revoke', {
      method: 'POST',
      headers: authHeaders(), // token tenant = uid-123
      body: JSON.stringify({ username: 'admin' }),
    }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { ended: number } };
    expect(body.data.ended).toBe(1);
    const endCalls = executeMock.mock.calls.filter((c) => {
      const sql = (c[0] as { sql: string }).sql;
      return sql.includes('UPDATE sessions') && sql.includes('ended_at = ?');
    });
    expect(endCalls.map((c) => (c[0] as { args: unknown[] }).args![1])).toEqual(['s-mine']);
  });

  // T14: /sessions/revoke is a cross-session weapon. A session admin may only
  // revoke its own username; only the Firebase owner may revoke anyone in the
  // tenant. The tenant scoping below is necessary but not sufficient.
  async function sessionTokenFor(usr: string, jti: string): Promise<string> {
    const nowS = Math.floor(Date.now() / 1000);
    seedSessionRow({ id: jti, username: usr });
    return mintSessionJwt(
      { tid: 'uid-123', usr, role: 'admin', jti, iat: nowS, exp: nowS + 3600 },
      SECRET,
    );
  }

  it('a session admin cannot revoke another admin (T14)', async () => {
    const token = await sessionTokenFor('adm-a', 'sess-t14-other');
    dbState.sessionRows.push({
      id: 'victim', tenant_id: 'uid-123', device_hwid: 'web', username: 'adm-b',
      started_at: 1, heartbeat_at: Date.now(), ended_at: null, source: 'web',
    });
    const app = makeApp();
    const res = await app.request('/sessions/revoke', {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify({ username: 'adm-b' }),
    }, env);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: string }).error).toBe('FORBIDDEN');
    const victim = dbState.sessionRows.find((s) => s['id'] === 'victim');
    expect(victim!['ended_at']).toBeNull();
  });

  it('a session admin can revoke their own sessions (T14)', async () => {
    const token = await sessionTokenFor('adm-a', 'sess-t14-self');
    dbState.sessionRows.push({
      id: 'own-other', tenant_id: 'uid-123', device_hwid: 'hw9', username: 'adm-a',
      started_at: 1, heartbeat_at: Date.now(), ended_at: null, source: 'pos',
    });
    const app = makeApp();
    const res = await app.request('/sessions/revoke', {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify({ username: 'adm-a' }),
    }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { ended: number } };
    expect(body.data.ended).toBe(2); // own live web row + own POS row
  });

  it('an owner can revoke any username in the tenant (T14)', async () => {
    dbState.sessionRows = [
      { id: 'o1', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'someone-else', started_at: 1, heartbeat_at: Date.now(), ended_at: null },
    ];
    const app = makeApp();
    const res = await app.request('/sessions/revoke', {
      method: 'POST',
      headers: authHeaders(), // Firebase owner token
      body: JSON.stringify({ username: 'someone-else' }),
    }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { ended: number } };
    expect(body.data.ended).toBe(1);
  });

  it('POST /auth/login 400 for each missing field individually', async () => {
    const app = makeApp();
    const cases = [
      { username: 'admin', password: 'secret1' }, // no tenant_id
      { tenant_id: 'uid-123', password: 'secret1' }, // no username
      { tenant_id: 'uid-123', username: 'admin' }, // no password
      { tenant_id: 'uid-123', username: '   ', password: 'secret1' }, // trim → empty
    ];
    for (const body of cases) {
      const res = await app.request('/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }, env);
      expect(res.status).toBe(400);
      expect(((await res.json()) as { error: string }).error).toBe('MISSING_FIELDS');
    }
  });
});

describe('carried from T05: real RS256 routing + session vars', () => {
  const SECRET = 'test-admin-jwt-secret';

  it('a REAL forged RS256 token passes requireAuth end-to-end (JWKS stubbed)', async () => {
    // Pure WebCrypto forge (no node:crypto — the api tsconfig is
    // workers-types; crypto.subtle covers keygen + sign in Node too).
    const keyPair = (await crypto.subtle.generateKey(
      {
        name: 'RSASSA-PKCS1-v1_5',
        modulusLength: 2048,
        publicExponent: new Uint8Array([1, 0, 1]),
        hash: 'SHA-256',
      },
      true,
      ['sign', 'verify'],
    )) as CryptoKeyPair;
    const jwk = await crypto.subtle.exportKey('jwk', keyPair.publicKey);
    const jwksFetch = vi.fn(() =>
      Promise.resolve(new Response(JSON.stringify({ keys: [{ ...jwk, kid: 'k1', alg: 'RS256' }] }), { status: 200 })),
    );
    vi.stubGlobal('fetch', jwksFetch);

    const enc = (obj: unknown) =>
      bytesToB64url(new TextEncoder().encode(JSON.stringify(obj)));
    const signData = async (header: string, payload: string) =>
      bytesToB64url(
        new Uint8Array(
          await crypto.subtle.sign(
            'RSASSA-PKCS1-v1_5',
            keyPair.privateKey,
            new TextEncoder().encode(`${header}.${payload}`),
          ),
        ),
      );
    const now = Math.floor(Date.now() / 1000);
    const claims = {
      aud: 'daftari-pos',
      iss: 'https://securetoken.google.com/daftari-pos',
      sub: 'uid-123',
      email: 'owner@daftari.co',
      exp: now + 3600,
      iat: now,
      email_verified: true,
      firebase: { identities: {}, sign_in_provider: 'google.com' },
    };
    const data = `${enc({ alg: 'RS256', kid: 'k1' })}.${enc(claims)}`;
    const token = `${data}.${await signData(data.split('.')[0]!, data.split('.')[1]!)}`;

    const { Hono } = await import('hono');
    const { getDb } = await import('../src/db');
    const { requireAuth } = await import('../src/middleware/auth');
    const app = new Hono<{ Bindings: Env; Variables: Vars }>();
    app.use('*', requireAuth({ db: getDb })); // NO verifyToken stub — real crypto.
    app.get('/echo', (c) =>
      c.json({ ok: true, uid: c.get('authUid'), isOwner: c.get('authIsOwner') }),
    );
    const res = await app.request('/echo', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { uid: string; isOwner: boolean };
    expect(body.uid).toBe('uid-123');
    expect(body.isOwner).toBe(true);

    const passwordData = `${enc({ alg: 'RS256', kid: 'k1' })}.${enc({ ...claims, firebase: { identities: {}, sign_in_provider: 'github.com' } })}`;
    const pwParts = passwordData.split('.');
    const forged = `${passwordData}.${await signData(pwParts[0]!, pwParts[1]!)}`;
    const rejected = await app.request('/echo', { headers: authHeaders(forged) }, env);
    expect(rejected.status).toBe(401);
    expect(((await rejected.json()) as { error: string }).error).toBe('PROVIDER_NOT_ALLOWED');

    vi.unstubAllGlobals();
  });

  it('session token surfaces authUsername/authRole end-to-end', async () => {
    const nowS = Math.floor(Date.now() / 1000);
    const token = await mintSessionJwt(
      { tid: 'uid-123', usr: 'manager', role: 'admin', jti: 'sess-echo', iat: nowS, exp: nowS + 3600 },
      SECRET,
    );
    seedSessionRow({ id: 'sess-echo', username: 'manager' });
    const { Hono } = await import('hono');
    const { getDb } = await import('../src/db');
    const { requireAuth } = await import('../src/middleware/auth');
    const app = new Hono<{ Bindings: Env; Variables: Vars }>();
    app.use('*', requireAuth({ verifyToken: verifyTokenStub, db: getDb }));
    app.get('/echo', (c) =>
      c.json({
        username: c.get('authUsername'),
        role: c.get('authRole'),
        isOwner: c.get('authIsOwner'),
      }),
    );
    const res = await app.request('/echo', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { username?: string; role?: string; isOwner: boolean };
    expect(body.username).toBe('manager');
    expect(body.role).toBe('admin');
    expect(body.isOwner).toBe(false);
  });
});

describe('users CRUD routes (admin-dashboard T07)', () => {
  const SECRET = 'test-admin-jwt-secret';
  const nowS = () => Math.floor(Date.now() / 1000);

  async function sessionToken(role = 'admin'): Promise<string> {
    seedSessionRow({ id: 'sess-users', username: 'boss' });
    return mintSessionJwt(
      { tid: 'uid-123', usr: 'boss', role, jti: 'sess-users', iat: nowS(), exp: nowS() + 3600 },
      SECRET,
    );
  }

  const seededRow = (username: string, role = 'admin') => ({
    tenant_id: 'uid-123',
    username,
    password_hash: 'old-hash',
    role,
    display_name: null,
    must_change_password: 0,
    is_active: 1,
    failed_attempts: 0,
    locked_until: 777,
    created_at: 1,
    updated_at: 2,
  });

  it('GET /admin/users lists users without secrets (owner token)', async () => {
    dbState.authUserRows = [seededRow('boss')];
    const app = makeApp();
    const res = await app.request('/admin/users', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { data: { users: Array<Record<string, unknown>> } };
    expect(body.data.users).toHaveLength(1);
    expect(body.data.users[0]!['username']).toBe('boss');
    expect(body.data.users[0]).not.toHaveProperty('password_hash');
    expect(body.data.users[0]).not.toHaveProperty('locked_until');
    expect(body.data.users[0]).not.toHaveProperty('failed_attempts');
  });

  it('GET /admin/users works with a session token (dual auth)', async () => {
    dbState.authUserRows = [seededRow('boss')];
    const app = makeApp();
    const res = await app.request('/admin/users', { headers: authHeaders(await sessionToken()) }, env);
    expect(res.status).toBe(200);
  });

  it('POST /admin/users: owner creates an admin with a verifiable hash → 201', async () => {
    dbState.authUserRows = [];
    const app = makeApp();
    const res = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ username: 'mgr', password: 'longenough12', role: 'admin', display_name: 'M' }),
    }, env);
    expect(res.status).toBe(201);
    const body = (await res.json()) as { data: { user: { username: string } } };
    expect(body.data.user.username).toBe('mgr');
    const insert = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('INSERT INTO auth_users'),
    );
    const storedHash = (insert![0] as { args: unknown[] }).args![2] as string;
    await expect(verifyTagged(storedHash, 'longenough12')).resolves.toBe(true);
  });

  it('POST /admin/users: owner creates a cashier → 201', async () => {
    dbState.authUserRows = [];
    const app = makeApp();
    const res = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ username: 'cash1', password: 'longenough12', role: 'cashier' }),
    }, env);
    expect(res.status).toBe(201);
  });

  it('POST /admin/users: session-admin creates a cashier → 201', async () => {
    dbState.authUserRows = [];
    const app = makeApp();
    const res = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(await sessionToken()),
      body: JSON.stringify({ username: 'cash2', password: 'longenough12', role: 'cashier' }),
    }, env);
    expect(res.status).toBe(201);
  });

  it('POST /admin/users: session-admin creating an admin → 403 ADMIN_MANAGEMENT_OWNER_ONLY', async () => {
    const app = makeApp();
    const res = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(await sessionToken()),
      body: JSON.stringify({ username: 'mgr2', password: 'longenough12', role: 'admin' }),
    }, env);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: string }).error).toBe('ADMIN_MANAGEMENT_OWNER_ONLY');
  });

  it('POST /admin/users rejects invalid usernames, short passwords, and bad roles → 400', async () => {
    const app = makeApp();
    const cases = [
      { username: 'ab', password: 'longenough12', role: 'cashier' }, // too short
      { username: 'bad name!', password: 'longenough12', role: 'cashier' }, // bad chars
      { username: 'valid_user', password: 'short', role: 'cashier' }, // password < 8
      { username: 'valid_user', password: 'longenough12', role: 'superuser' }, // bad role
    ];
    for (const body of cases) {
      const res = await app.request('/admin/users', {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify(body),
      }, env);
      expect(res.status).toBe(400);
      expect(((await res.json()) as { error: string }).error).toBe('INVALID_FIELDS');
    }
  });

  it('POST /admin/users duplicate username → 409', async () => {
    dbState.authUserRows = [seededRow('dup')];
    const app = makeApp();
    const res = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ username: 'dup', password: 'longenough12', role: 'cashier' }),
    }, env);
    expect(res.status).toBe(409);
    expect(((await res.json()) as { error: string }).error).toBe('USERNAME_TAKEN');
  });

  it('PATCH /admin/users/:username by a session token → 403 OWNER_ONLY', async () => {
    dbState.authUserRows = [seededRow('boss')];
    const app = makeApp();
    const res = await app.request('/admin/users/boss', {
      method: 'PATCH',
      headers: authHeaders(await sessionToken()),
      body: JSON.stringify({ password: 'newlongenough' }),
    }, env);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: string }).error).toBe('OWNER_ONLY');
  });

  it('PATCH by owner sets a new verifiable password → 200', async () => {
    dbState.authUserRows = [seededRow('boss')];
    const app = makeApp();
    const res = await app.request('/admin/users/boss', {
      method: 'PATCH',
      headers: authHeaders(),
      body: JSON.stringify({ password: 'newlongenough', display_name: 'The Boss' }),
    }, env);
    expect(res.status).toBe(200);
    const update = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('UPDATE auth_users'),
    );
    const newHash = (update![0] as { args: unknown[] }).args![0] as string;
    await expect(verifyTagged(newHash, 'newlongenough')).resolves.toBe(true);
  });

  it('PATCH missing user → 404; short password → 400', async () => {
    dbState.authUserRows = [];
    const app = makeApp();
    const missing = await app.request('/admin/users/ghost', {
      method: 'PATCH',
      headers: authHeaders(),
      body: JSON.stringify({ password: 'newlongenough' }),
    }, env);
    expect(missing.status).toBe(404);

    dbState.authUserRows = [seededRow('boss')];
    const shortPw = await app.request('/admin/users/boss', {
      method: 'PATCH',
      headers: authHeaders(),
      body: JSON.stringify({ password: 'short' }),
    }, env);
    expect(shortPw.status).toBe(400);
  });

  it('DELETE by owner soft-deactivates → 200; missing → 404', async () => {
    dbState.authUserRows = [seededRow('boss')];
    const app = makeApp();
    const res = await app.request('/admin/users/boss', { method: 'DELETE', headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const update = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('is_active = ?'),
    );
    expect((update![0] as { args: unknown[] }).args![0]).toBe(0);

    dbState.authUserRows = [];
    const missing = await app.request('/admin/users/ghost', { method: 'DELETE', headers: authHeaders() }, env);
    expect(missing.status).toBe(404);
  });

  it('unauthenticated requests to /admin/users* → 401 (registration-order pin)', async () => {
    const app = makeApp();
    const get = await app.request('/admin/users', {}, env);
    expect(get.status).toBe(401);
    const patch = await app.request('/admin/users/boss', { method: 'PATCH' }, env);
    expect(patch.status).toBe(401);
    const del = await app.request('/admin/users/boss', { method: 'DELETE' }, env);
    expect(del.status).toBe(401);
  });

  it('POST rejects mistyped (non-string) fields → 400, never 500', async () => {
    const app = makeApp();
    const cases = [
      { username: 42, password: 'longenough12', role: 'cashier' },
      { username: 'valid_user', password: 4, role: 'cashier' },
      { username: 'valid_user', password: 'longenough12', role: 'cashier', display_name: 42 },
      { username: 'valid_user', password: 'longenough12', role: 42 }, // role typeof
    ];
    for (const body of cases) {
      const res = await app.request('/admin/users', {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify(body),
      }, env);
      expect(res.status).toBe(400);
      expect(((await res.json()) as { error: string }).error).toBe('INVALID_FIELDS');
    }
  });

  it('GET /admin/users pins the full wire shape (toEqual: extra keys fail)', async () => {
    dbState.authUserRows = [{ ...seededRow('boss'), display_name: 'The Boss' }];
    const app = makeApp();
    const res = await app.request('/admin/users', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const users = ((await res.json()) as { data: { users: Array<Record<string, unknown>> } }).data.users;
    expect(users[0]).toEqual({
      tenant_id: 'uid-123',
      username: 'boss',
      role: 'admin',
      display_name: 'The Boss',
      must_change_password: 0,
      is_active: 1,
      created_at: 1,
      updated_at: 2,
    });
  });

  it('GET /admin/users returns an empty list when no accounts exist', async () => {
    dbState.authUserRows = [];
    const app = makeApp();
    const res = await app.request('/admin/users', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { users: unknown[] } };
    expect(body.ok).toBe(true);
    expect(body.data.users).toEqual([]);
  });

  it('POST trims whitespace-only display_name to NULL + pins insert args', async () => {
    dbState.authUserRows = [];
    const app = makeApp();
    const res = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ username: 'trim1', password: 'longenough12', role: 'cashier', display_name: '   ' }),
    }, env);
    expect(res.status).toBe(201);
    const insert = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('INSERT INTO auth_users'),
    );
    const args = (insert![0] as { args: unknown[] }).args!;
    expect(args[3]).toBe('cashier'); // role
    expect(args[4]).toBeNull(); // display_name trimmed to NULL
  });

  it('PATCH display_name only → no password_hash in SET', async () => {
    dbState.authUserRows = [seededRow('boss')];
    const app = makeApp();
    const res = await app.request('/admin/users/boss', {
      method: 'PATCH',
      headers: authHeaders(),
      body: JSON.stringify({ display_name: '  Renamed  ' }),
    }, env);
    expect(res.status).toBe(200);
    const update = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('UPDATE auth_users'),
    );
    const call = update![0] as { sql: string; args: unknown[] };
    expect(call.sql).not.toContain('password_hash = ?');
    expect(call.args![0]).toBe('Renamed'); // trimmed
  });

  it('PATCH password only → SET has password_hash, no display_name', async () => {
    dbState.authUserRows = [seededRow('boss')];
    const app = makeApp();
    const res = await app.request('/admin/users/boss', {
      method: 'PATCH',
      headers: authHeaders(),
      body: JSON.stringify({ password: 'newlongenough' }),
    }, env);
    expect(res.status).toBe(200);
    const update = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('UPDATE auth_users'),
    );
    const call = update![0] as { sql: string; args: unknown[] };
    expect(call.sql).toContain('password_hash = ?');
    expect(call.sql).not.toContain('display_name = ?');
  });

  it('PATCH is_active only → is_active in SET, no password_hash', async () => {
    dbState.authUserRows = [seededRow('boss')];
    const app = makeApp();
    const res = await app.request('/admin/users/boss', {
      method: 'PATCH',
      headers: authHeaders(),
      body: JSON.stringify({ is_active: 0 }),
    }, env);
    expect(res.status).toBe(200);
    const update = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('UPDATE auth_users'),
    );
    const call = update![0] as { sql: string; args: unknown[] };
    expect(call.sql).not.toContain('password_hash = ?');
    expect(call.sql).toContain('is_active = ?');
    expect(call.args![0]).toBe(0);
  });

  it('PATCH with no recognized field (or whitespace display_name) → 400', async () => {
    dbState.authUserRows = [seededRow('boss')];
    const app = makeApp();
    const empty = await app.request('/admin/users/boss', {
      method: 'PATCH',
      headers: authHeaders(),
      body: JSON.stringify({}),
    }, env);
    expect(empty.status).toBe(400);
    const blankName = await app.request('/admin/users/boss', {
      method: 'PATCH',
      headers: authHeaders(),
      body: JSON.stringify({ display_name: '   ' }),
    }, env);
    expect(blankName.status).toBe(400);
  });

  it('POST enforces the username length bounds (30 ok, 31 → 400)', async () => {
    dbState.authUserRows = [];
    const app = makeApp();
    const ok = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ username: 'a'.repeat(30), password: 'longenough12', role: 'cashier' }),
    }, env);
    expect(ok.status).toBe(201);
    const tooLong = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ username: 'a'.repeat(31), password: 'longenough12', role: 'cashier' }),
    }, env);
    expect(tooLong.status).toBe(400);
  });

  it('PATCH rejects mistyped/invalid fields → 400 (guard rejection branches)', async () => {
    dbState.authUserRows = [seededRow('boss')];
    const app = makeApp();
    const cases = [
      { password: 4 }, // PATCH password typeof guard
      { display_name: 42 }, // PATCH display_name typeof guard
      { is_active: 2 }, // integer but not 0|1
      { is_active: 1.5 }, // non-integer
      { is_active: '1' }, // string
    ];
    for (const body of cases) {
      const res = await app.request('/admin/users/boss', {
        method: 'PATCH',
        headers: authHeaders(),
        body: JSON.stringify(body),
      }, env);
      expect(res.status).toBe(400);
      expect(((await res.json()) as { error: string }).error).toBe('INVALID_FIELDS');
    }
  });

  it('PATCH is_active: 1 → 200 with is_active in SET', async () => {
    dbState.authUserRows = [seededRow('boss')];
    const app = makeApp();
    const res = await app.request('/admin/users/boss', {
      method: 'PATCH',
      headers: authHeaders(),
      body: JSON.stringify({ is_active: 1 }),
    }, env);
    expect(res.status).toBe(200);
    const update = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('UPDATE auth_users'),
    );
    const call = update![0] as { sql: string; args: unknown[] };
    expect(call.sql).toContain('is_active = ?');
    expect(call.args![0]).toBe(1);
  });
});

describe('admin devices + activity routes (admin-dashboard T08)', () => {
  const deviceRow = (hwid: string, name: string) => ({
    tenant_id: 'uid-123',
    device_hwid: hwid,
    device_name: name,
    platform: 'linux',
    first_seen_at: 1,
    last_seen_at: Date.now(),
  });

  it('GET /admin/devices joins active sessions per device', async () => {
    dbState.deviceRows = [deviceRow('hw1', 'Main Counter'), deviceRow('hw2', 'Back Office')];
    dbState.sessionRows = [
      { id: 's1', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'admin', started_at: 5, heartbeat_at: Date.now(), ended_at: null, source: 'pos' },
    ];
    const app = makeApp();
    const res = await app.request('/admin/devices', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      data: { devices: Array<{ device_hwid: string; active_session?: { id: string; username: string } }> };
    };
    const withSession = body.data.devices.find((d) => d.device_hwid === 'hw1');
    expect(withSession?.active_session?.id).toBe('s1');
    expect(withSession?.active_session?.username).toBe('admin');
    const without = body.data.devices.find((d) => d.device_hwid === 'hw2');
    expect(without?.active_session).toBeUndefined();
  });

  it('GET /admin/devices does not join web-session rows to devices', async () => {
    dbState.deviceRows = [deviceRow('hw1', 'Main Counter')];
    dbState.sessionRows = [
      { id: 's-web', tenant_id: 'uid-123', device_hwid: 'web', username: 'admin', started_at: 5, heartbeat_at: Date.now(), ended_at: null, source: 'web' },
    ];
    const app = makeApp();
    const res = await app.request('/admin/devices', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      data: { devices: Array<{ device_hwid: string; active_session?: unknown }> };
    };
    expect(body.data.devices[0]!.active_session).toBeUndefined();
  });

  it('GET /admin/activity merges sales + sessions sorted desc (last 10)', async () => {
    const now = Date.now();
    dbState.saleRows = [
      { id: 'sale-1', tenant_id: 'uid-123', receipt_json: '{}', total_piastres: 5000, created_at: now - 60_000 },
      { id: 'sale-2', tenant_id: 'uid-123', receipt_json: '{}', total_piastres: 12000, created_at: now - 30_000 },
    ];
    dbState.sessionRows = [
      { id: 's1', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'admin', started_at: now - 10_000, heartbeat_at: now, ended_at: null, source: 'pos' },
    ];
    const app = makeApp();
    const res = await app.request('/admin/activity', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      data: { events: Array<{ type: string; at: number; summary: string }> };
    };
    expect(body.data.events).toHaveLength(3);
    expect(body.data.events[0]!.type).toBe('session'); // newest
    expect(body.data.events[0]!.summary).toContain('admin');
    expect(body.data.events[1]!.type).toBe('sale');
    expect(body.data.events[1]!.summary).toContain('12000');
    expect(body.data.events[2]!.summary).toContain('5000');
  });

  it('GET /admin/activity returns an empty list with no data', async () => {
    dbState.saleRows = [];
    dbState.sessionRows = [];
    const app = makeApp();
    const res = await app.request('/admin/activity', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { data: { events: unknown[] } };
    expect(body.data.events).toEqual([]);
  });

  it('GET /admin/devices requires the admin role → 403 otherwise', async () => {
    dbState.userRows = [{ tenant_id: 'uid-123', email: 'o@d.co', role: 'cashier', created_at: 1 }];
    const app = makeApp();
    const res = await app.request('/admin/devices', { headers: authHeaders() }, env);
    expect(res.status).toBe(403);
  });

  it('GET /admin/activity requires the admin role → 403 otherwise', async () => {
    dbState.userRows = [{ tenant_id: 'uid-123', email: 'o@d.co', role: 'cashier', created_at: 1 }];
    const app = makeApp();
    const res = await app.request('/admin/activity', { headers: authHeaders() }, env);
    expect(res.status).toBe(403);
  });

  it('GET /admin/activity caps the merged feed at 10 (12 seeded)', async () => {
    // 6 sales + 6 sessions → 12 raw events. The route's own pipeline drops
    // 2: sales.slice(-5) drops the oldest sale, then the 10-event cap drops
    // the next-oldest event. The mock ignores SQL LIMIT/ORDER, so all 6
    // session rows reach the route (real SQL caps at 5). (T08 coverage round 2.)
    const now = Date.now();
    const minute = 60_000;
    // saleRows seeded ascending (ORDER BY created_at ASC contract) so
    // slice(-5) takes the 5 newest like production.
    dbState.saleRows = [11, 9, 7, 5, 3, 1].map((i) => ({
      id: `sale-${i}`, tenant_id: 'uid-123', receipt_json: '{}', total_piastres: i * 100, created_at: now - i * minute,
    }));
    // getRecentSessions returns DESC rows (mock ignores LIMIT 5 → 6 rows).
    dbState.sessionRows = [12, 10, 8, 6, 4, 2].map((i) => ({
      id: `sess-${i}`, tenant_id: 'uid-123', device_hwid: `hw-${i}`, username: 'admin', started_at: now - i * minute, heartbeat_at: now, ended_at: null, source: 'pos',
    }));
    const app = makeApp();
    const res = await app.request('/admin/activity', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      data: { events: Array<{ type: string; at: number; summary: string }> };
    };
    expect(body.data.events).toHaveLength(10);
    expect(body.data.events[0]).toEqual({
      type: 'sale',
      at: now - minute,
      summary: '100 piastres',
    }); // newest survives
    const ats = body.data.events.map((e) => e.at);
    expect(ats).not.toContain(now - 11 * minute); // oldest sale: dropped by slice(-5)
    expect(ats).not.toContain(now - 12 * minute); // 11th oldest: dropped by the cap
    expect(ats).toEqual([
      now - 1 * minute,
      now - 2 * minute,
      now - 3 * minute,
      now - 4 * minute,
      now - 5 * minute,
      now - 6 * minute,
      now - 7 * minute,
      now - 8 * minute,
      now - 9 * minute,
      now - 10 * minute,
    ]);
  });

  it('unauthenticated /admin/devices and /admin/activity → 401', async () => {
    const app = makeApp();
    expect((await app.request('/admin/devices', {}, env)).status).toBe(401);
    expect((await app.request('/admin/activity', {}, env)).status).toBe(401);
  });

  it('GET /admin/devices pins the full wire shape (toEqual: extra keys fail)', async () => {
    dbState.deviceRows = [deviceRow('hw1', 'Main Counter')];
    dbState.sessionRows = [
      { id: 's1', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'admin', started_at: 5, heartbeat_at: Date.now(), ended_at: null, source: 'pos' },
    ];
    const app = makeApp();
    const res = await app.request('/admin/devices', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { data: { devices: Array<Record<string, unknown>> } };
    expect(body.data.devices[0]).toEqual({
      tenant_id: 'uid-123',
      device_hwid: 'hw1',
      device_name: 'Main Counter',
      platform: 'linux',
      first_seen_at: 1,
      last_seen_at: expect.any(Number),
      // Session fields (heartbeat_at, source, tenant_id) must not leak.
      active_session: { id: 's1', username: 'admin', started_at: 5 },
    });
  });
});

describe('session resume (T11)', () => {
  const SECRET = 'test-admin-jwt-secret';
  const nowS = () => Math.floor(Date.now() / 1000);
  function sessionJwtFor(jti: string, tenantId = 'uid-123'): Promise<string> {
    return mintSessionJwt(
      { tid: tenantId, usr: 'admin', role: 'admin', jti, iat: nowS(), exp: nowS() + 3600 },
      SECRET,
    );
  }

  it('resumes a live session: same jti, fresh token, session_id, profile', async () => {
    seedSessionRow({ id: 'resume-1' });
    const app = makeApp();
    const res = await app.request('/auth/session/resume', {
      method: 'POST',
      headers: authHeaders(await sessionJwtFor('resume-1')),
    }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      ok: boolean;
      data: { token: string; session_id: string; profile: { tenant_id: string } | null };
    };
    expect(body.ok).toBe(true);
    expect(body.data.session_id).toBe('resume-1');
    expect(body.data.profile).not.toBeNull();
    expect(body.data.profile!.tenant_id).toBe('uid-123');
    const claims = await verifySessionJwt(body.data.token, SECRET);
    expect(claims?.jti).toBe('resume-1');
    expect(claims?.tid).toBe('uid-123');
    expect(claims!.exp - claims!.iat).toBe(12 * 3600);
  });

  it('rejects resume for an ended (revoked) session → 401 SESSION_REVOKED', async () => {
    seedSessionRow({ id: 'resume-ended', ended_at: Date.now() });
    const app = makeApp();
    const res = await app.request('/auth/session/resume', {
      method: 'POST',
      headers: authHeaders(await sessionJwtFor('resume-ended')),
    }, env);
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: string }).error).toBe('SESSION_REVOKED');
  });

  it('the resumed token authenticates a subsequent request', async () => {
    seedSessionRow({ id: 'resume-live' });
    const app = makeApp();
    const resumed = await app.request('/auth/session/resume', {
      method: 'POST',
      headers: authHeaders(await sessionJwtFor('resume-live')),
    }, env);
    expect(resumed.status).toBe(200);
    const { data } = (await resumed.json()) as { data: { token: string } };
    const me = await app.request('/auth/me', { headers: authHeaders(data.token) }, env);
    expect(me.status).toBe(200);
    const body = (await me.json()) as { data: { profile: { tenant_id: string } } };
    expect(body.data.profile.tenant_id).toBe('uid-123');
  });

  it('resume whose jti names no live row → 401 SESSION_REVOKED', async () => {
    const app = makeApp();
    const res = await app.request('/auth/session/resume', {
      method: 'POST',
      headers: authHeaders(await sessionJwtFor('ghost-resume')),
    }, env);
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: string }).error).toBe('SESSION_REVOKED');
  });
});

describe('atomic session admission (T12)', () => {
  it('insertSession reports false when a live web session already exists', async () => {
    dbState.sessionRows = [];
    const db = createTurso('https://test.turso.io', 'turso-token');
    const base = {
      tenant_id: 'uid-123',
      device_hwid: 'web',
      username: 'admin',
      started_at: 1,
      heartbeat_at: 1,
      source: 'web' as const,
    };
    await expect(db.insertSession({ id: 'w1', ...base })).resolves.toBe(true);
    await expect(db.insertSession({ id: 'w2', ...base })).resolves.toBe(false);
    expect(
      dbState.sessionRows.filter((s) => s['source'] === 'web' && s['ended_at'] == null),
    ).toHaveLength(1);
  });

  it('admitPosSession rejects an over-limit device but admits a reconnect', async () => {
    dbState.sessionRows = [
      { id: 'p1', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'admin', started_at: 1, heartbeat_at: 1, ended_at: null, source: 'pos' },
    ];
    const db = createTurso('https://test.turso.io', 'turso-token');
    await expect(
      db.admitPosSession(
        { id: 'p2', tenant_id: 'uid-123', device_hwid: 'hw2', username: 'admin', started_at: 2, heartbeat_at: 2, source: 'pos' },
        1,
      ),
    ).resolves.toBe(false);
    await expect(
      db.admitPosSession(
        { id: 'p3', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'admin', started_at: 3, heartbeat_at: 3, source: 'pos' },
        1,
      ),
    ).resolves.toBe(true);
    expect(dbState.sessionRows.filter((s) => s['ended_at'] == null)).toHaveLength(2);
  });

  it('/sessions/start surfaces a rejected atomic admission as 409', async () => {
    // The early count check is only a fast path; this proves the route also
    // handles the authoritative conditional INSERT reporting no row written.
    const fakeDb = {
      getUser: async () => ({ tenant_id: 'uid-123', email: 'o@d.co', role: 'admin', tier: 'starter', created_at: 1 }),
      getActivePosSessions: async () => [],
      upsertDevice: async () => undefined,
      admitPosSession: async () => false,
      endSessionForDevice: async () => undefined,
    };
    const app = createApp({
      verifyToken: verifyTokenStub,
      getDb: () => fakeDb as never,
      postHogFetch: () => Promise.resolve(new Response('{}', { status: 200 })),
    });
    const res = await app.request('/sessions/start', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ device_hwid: 'hw-race' }),
    }, env);
    expect(res.status).toBe(409);
  });
});

describe('CORS allowlist (T19)', () => {
  const devEnv = { ...env, ENVIRONMENT: 'development' };
  const stagingEnv = { ...env, ENVIRONMENT: 'staging' };
  const prodEnv = { ...env, ENVIRONMENT: 'production' };

  it('a foreign origin is not echoed in Access-Control-Allow-Origin', async () => {
    const app = makeApp();
    const res = await app.request('/health', { headers: { Origin: 'https://evil.example' } }, prodEnv);
    expect(res.headers.get('Access-Control-Allow-Origin')).toBeNull();
  });

  it('the admin origin is echoed', async () => {
    const app = makeApp();
    const prod = await app.request('/health', { headers: { Origin: 'https://admin.daftariapp.workers.dev' } }, prodEnv);
    expect(prod.headers.get('Access-Control-Allow-Origin')).toBe('https://admin.daftariapp.workers.dev');
    const staging = await app.request('/health', { headers: { Origin: 'https://admin-staging.daftariapp.workers.dev' } }, stagingEnv);
    expect(staging.headers.get('Access-Control-Allow-Origin')).toBe('https://admin-staging.daftariapp.workers.dev');
    // An origin valid in another environment is not valid here.
    const cross = await app.request('/health', { headers: { Origin: 'https://admin-dev.daftariapp.workers.dev' } }, prodEnv);
    expect(cross.headers.get('Access-Control-Allow-Origin')).toBeNull();
  });

  it('localhost is allowed in development only', async () => {
    const app = makeApp();
    const dev = await app.request('/health', { headers: { Origin: 'http://localhost:3000' } }, devEnv);
    expect(dev.headers.get('Access-Control-Allow-Origin')).toBe('http://localhost:3000');
    const loopback = await app.request('/health', { headers: { Origin: 'http://127.0.0.1:5173' } }, devEnv);
    expect(loopback.headers.get('Access-Control-Allow-Origin')).toBe('http://127.0.0.1:5173');
    const prod = await app.request('/health', { headers: { Origin: 'http://localhost:3000' } }, prodEnv);
    expect(prod.headers.get('Access-Control-Allow-Origin')).toBeNull();
  });

  it('OPTIONS preflight advertises the explicit allow headers', async () => {
    const app = makeApp();
    const res = await app.request('/health', {
      method: 'OPTIONS',
      headers: {
        Origin: 'https://admin.daftariapp.workers.dev',
        'Access-Control-Request-Headers': 'Authorization',
      },
    }, prodEnv);
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe('https://admin.daftariapp.workers.dev');
    expect(res.headers.get('Access-Control-Allow-Headers')).toBe('Authorization,Content-Type');
  });
});
