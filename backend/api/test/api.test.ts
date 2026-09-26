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
}
const dbState: DbState = {
  userRows: [],
  sessionRows: [],
  saleRows: [],
  licenseRows: [],
  authUserRows: [],
};

const realtimeNotify = vi.fn(() => Promise.resolve());
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
  REALTIME: { notify: realtimeNotify },
  LOGOS: { put: logosPut, get: logosGet },
};

function makeApp() {
  return createApp({ verifyToken: verifyTokenStub, postHogFetch: () => Promise.resolve(new Response('{"status":"Ok"}', { status: 200 })) });
}

function authHeaders(token = 'valid-uid-123') {
  return { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
}

beforeEach(() => {
  vi.clearAllMocks();
  dbState.userRows = [{ tenant_id: 'uid-123', email: 'owner@daftari.co', role: 'admin', tier: 'starter', created_at: 1, last_login_at: 2, last_owner_login_at: Date.now() }];
  dbState.sessionRows = [];
  dbState.saleRows = [];
  dbState.licenseRows = [{ tenant_id: 'uid-123', device_hwid: 'hw1', license_key: 'k', subscription_end: 9, billing_cycle: 'monthly', grace_end: 9, status: 'active', created_at: 1 }];
  dbState.authUserRows = [];

  executeMock.mockImplementation(({ sql, args }: { sql: string; args?: unknown[] }) => {
    // Per-username active-session query (login conflict check, T06):
    // simulate the heartbeat + username + tenant filters.
    if (sql.includes('heartbeat_at > ?')) {
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
    if (sql.includes("source != 'web'")) {
      const rows = dbState.sessionRows.filter(
        (s) => s['ended_at'] == null && s['source'] !== 'web',
      );
      return Promise.resolve({ rows, columns: [], rowsAffected: 0 });
    }
    if (sql.includes('FROM auth_users')) return Promise.resolve({ rows: dbState.authUserRows, columns: [], rowsAffected: 0 });
    if (sql.includes('FROM users')) return Promise.resolve({ rows: dbState.userRows, columns: [], rowsAffected: 0 });
    if (sql.includes('FROM sessions')) return Promise.resolve({ rows: dbState.sessionRows.filter((s) => s['ended_at'] == null), columns: [], rowsAffected: 0 });
    if (sql.includes('FROM sales')) return Promise.resolve({ rows: dbState.saleRows, columns: [], rowsAffected: 0 });
    if (sql.includes('FROM licenses')) return Promise.resolve({ rows: dbState.licenseRows, columns: [], rowsAffected: 0 });
    if (sql.includes('INSERT INTO sessions')) {
      return Promise.resolve({ rows: [], columns: [], rowsAffected: 1 });
    }
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
    dbState.sessionRows = [{ id: 's1', tenant_id: 'uid-123', device_hwid: 'hw1', username: 'admin', started_at: 1, heartbeat_at: 2 }];
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
    const app = makeApp();
    const res = await app.request('/sessions/heartbeat', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ session_id: 's1' }),
    }, env);
    expect(res.status).toBe(200);
    const calls = executeMock.mock.calls.filter((c) => (c[0] as { sql: string }).sql.includes('UPDATE sessions SET heartbeat_at'));
    expect(calls.length).toBe(1);
  });

  it('POST /sessions/end closes the session', async () => {
    const app = makeApp();
    const res = await app.request('/sessions/end', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ session_id: 's1' }),
    }, env);
    expect(res.status).toBe(200);
    const calls = executeMock.mock.calls.filter((c) => (c[0] as { sql: string }).sql.includes('ended_at = ?'));
    expect(calls.length).toBe(1);
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
  it('POST /sales/sync writes sales + notifies realtime binding', async () => {
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
    expect(realtimeNotify).toHaveBeenCalledWith('uid-123', expect.objectContaining({ type: 'sale' }));
  });

  it('GET /sales?since=100 returns rows', async () => {
    dbState.saleRows = [{ id: 'r1', tenant_id: 'uid-123', receipt_json: '{}', total_piastres: 500, created_at: 150 }];
    const app = makeApp();
    const res = await app.request('/sales?since=100', { headers: authHeaders() }, env);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; data: { sales: unknown[] } };
    expect(body.data.sales).toHaveLength(1);
  });
});

describe('admin routes', () => {
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
    return mintSessionJwt(
      {
        tid: 'uid-123',
        usr: 'admin',
        role: 'admin',
        iat: nowS(),
        exp: nowS() + 3600,
        ...overrides,
      } as Parameters<typeof mintSessionJwt>[0],
      SECRET,
    );
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
      { tid: 'uid-123', usr: 'admin', role: 'admin', iat: nowS(), exp: nowS() + 3600 },
      'wrong-secret',
    );
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe('Invalid session token');
  });

  it('rejects an expired session JWT → 401', async () => {
    const token = await mintSession({ exp: nowS() - 1 });
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe('Invalid session token');
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

  it('rejects a Firebase token with a disallowed sign_in_provider → 401 PROVIDER_NOT_ALLOWED', async () => {
    verifyTokenStub.mockResolvedValueOnce({
      valid: true,
      uid: 'uid-123',
      email: 'o@d.co',
      signInProvider: 'password',
      emailVerified: true,
    });
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders('fb-token') }, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe('PROVIDER_NOT_ALLOWED');
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
    expect(realtimeNotify).toHaveBeenCalledWith('uid-123', {
      type: 'session_revoked',
      username: 'admin',
      at: expect.any(Number),
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
      { tid: 'uid-123', usr: 'admin', role: 'admin', iat: nowS, exp: nowS + 3600 },
      SECRET,
    );
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
    expect(realtimeNotify).not.toHaveBeenCalled();
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

    const passwordData = `${enc({ alg: 'RS256', kid: 'k1' })}.${enc({ ...claims, firebase: { identities: {}, sign_in_provider: 'password' } })}`;
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
      { tid: 'uid-123', usr: 'manager', role: 'admin', iat: nowS, exp: nowS + 3600 },
      SECRET,
    );
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
    return mintSessionJwt(
      { tid: 'uid-123', usr: 'boss', role, iat: nowS(), exp: nowS() + 3600 },
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
      body: JSON.stringify({ username: 'mgr', password: 'longenough1', role: 'admin', display_name: 'M' }),
    }, env);
    expect(res.status).toBe(201);
    const body = (await res.json()) as { data: { user: { username: string } } };
    expect(body.data.user.username).toBe('mgr');
    const insert = executeMock.mock.calls.find((c) =>
      (c[0] as { sql: string }).sql.includes('INSERT INTO auth_users'),
    );
    const storedHash = (insert![0] as { args: unknown[] }).args![2] as string;
    await expect(verifyTagged(storedHash, 'longenough1')).resolves.toBe(true);
  });

  it('POST /admin/users: owner creates a cashier → 201', async () => {
    dbState.authUserRows = [];
    const app = makeApp();
    const res = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ username: 'cash1', password: 'longenough1', role: 'cashier' }),
    }, env);
    expect(res.status).toBe(201);
  });

  it('POST /admin/users: session-admin creates a cashier → 201', async () => {
    dbState.authUserRows = [];
    const app = makeApp();
    const res = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(await sessionToken()),
      body: JSON.stringify({ username: 'cash2', password: 'longenough1', role: 'cashier' }),
    }, env);
    expect(res.status).toBe(201);
  });

  it('POST /admin/users: session-admin creating an admin → 403 ADMIN_MANAGEMENT_OWNER_ONLY', async () => {
    const app = makeApp();
    const res = await app.request('/admin/users', {
      method: 'POST',
      headers: authHeaders(await sessionToken()),
      body: JSON.stringify({ username: 'mgr2', password: 'longenough1', role: 'admin' }),
    }, env);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: string }).error).toBe('ADMIN_MANAGEMENT_OWNER_ONLY');
  });

  it('POST /admin/users rejects invalid usernames, short passwords, and bad roles → 400', async () => {
    const app = makeApp();
    const cases = [
      { username: 'ab', password: 'longenough1', role: 'cashier' }, // too short
      { username: 'bad name!', password: 'longenough1', role: 'cashier' }, // bad chars
      { username: 'valid_user', password: 'short', role: 'cashier' }, // password < 8
      { username: 'valid_user', password: 'longenough1', role: 'superuser' }, // bad role
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
      body: JSON.stringify({ username: 'dup', password: 'longenough1', role: 'cashier' }),
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
});
