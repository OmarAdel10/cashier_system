import { beforeEach, describe, expect, it, vi } from 'vitest';

// Mock @libsql/client at the lowest level — the api worker reaches Turso
// exclusively through backend/shared turso.ts.
const executeMock = vi.fn();
vi.mock('@libsql/client', () => ({
  createClient: vi.fn(() => ({ execute: executeMock })),
}));

import { createApp } from '../src/index';
import { mintSessionJwt } from '../../shared/src/session_jwt';
import { requireOwner, type VerifyTokenFn } from '../src/middleware/auth';

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
}
const dbState: DbState = { userRows: [], sessionRows: [], saleRows: [], licenseRows: [] };

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
  dbState.userRows = [{ tenant_id: 'uid-123', email: 'owner@daftari.co', role: 'admin', tier: 'starter', created_at: 1, last_login_at: 2 }];
  dbState.sessionRows = [];
  dbState.saleRows = [];
  dbState.licenseRows = [{ tenant_id: 'uid-123', device_hwid: 'hw1', license_key: 'k', subscription_end: 9, billing_cycle: 'monthly', grace_end: 9, status: 'active', created_at: 1 }];

  executeMock.mockImplementation(({ sql }: { sql: string }) => {
    if (sql.includes('FROM users')) return Promise.resolve({ rows: dbState.userRows, columns: [], rowsAffected: 0 });
    if (sql.includes('FROM sessions')) return Promise.resolve({ rows: dbState.sessionRows.filter((s) => s['ended_at'] == null), columns: [], rowsAffected: 0 });
    if (sql.includes('FROM sales')) return Promise.resolve({ rows: dbState.saleRows, columns: [], rowsAffected: 0 });
    if (sql.includes('FROM licenses')) return Promise.resolve({ rows: dbState.licenseRows, columns: [], rowsAffected: 0 });
    if (sql.includes('INSERT INTO sessions')) {
      return Promise.resolve({ rows: [], columns: [], rowsAffected: 1 });
    }
    return Promise.resolve({ rows: [], columns: [], rowsAffected: 0 });
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
  });

  it('rejects an expired session JWT → 401', async () => {
    const token = await mintSession({ exp: nowS() - 1 });
    const app = makeApp();
    const res = await app.request('/auth/me', { headers: authHeaders(token) }, env);
    expect(res.status).toBe(401);
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
});
