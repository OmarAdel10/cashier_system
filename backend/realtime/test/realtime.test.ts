import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('@libsql/client', () => ({
  createClient: () => ({ execute: async () => ({ rows: [], columns: [], rowsAffected: 0 }) }),
}));

import { createRealtimeApp } from '../src/index';
import type { Env } from '../src/index';
import { mintSessionJwt } from '../../shared/src/session_jwt';

// Test-only: pretend the DO stub is sync-fetch with 101 upgrade.
const notifier = {
  notify: vi.fn(async (_tenantId: string, _event: Record<string, unknown>) => undefined),
  getClients: vi.fn(async () => 0),
  upsertConfig: vi.fn(async () => undefined),
  getConfig: vi.fn(async () => null),
  fetch: vi.fn(async () => new Response('ok', { status: 200 })),
};

const notifierNamespace = {
  idFromName: vi.fn((name: string) => name),
  get: vi.fn(() => notifier),
};

const INTERNAL_SECRET = 'test-internal-secret';

const env: Env = {
  NOTIFIER: notifierNamespace as unknown as Env['NOTIFIER'],
  FIREBASE_PROJECT_ID: 'daftari-pos',
  ADMIN_JWT_SECRET: 'test-rt-secret',
  INTERNAL_NOTIFY_SECRET: INTERNAL_SECRET,
};

const internalHeaders = {
  'Content-Type': 'application/json',
  'X-Internal-Secret': INTERNAL_SECRET,
};

const verifyTokenStub = vi.fn(async (token: string) => {
  if (token === 'valid-token') return { valid: true, uid: 'uid-123' };
  return { valid: false };
});

const app = createRealtimeApp({ verifyToken: verifyTokenStub });

describe('realtime worker routes', () => {
  beforeEach(() => {
    notifier.notify.mockClear();
    notifier.fetch.mockClear();
  });

  it('POST /internal/notify routes to the tenant DO and broadcasts', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'uid-123', event: 'sale', data: { n: 1 } }),
    }, env);
    expect(res.status).toBe(200);
    expect(notifierNamespace.idFromName).toHaveBeenCalledWith('uid-123');
    expect(notifier.notify).toHaveBeenCalledWith('uid-123', expect.objectContaining({ type: 'sale', n: 1 }));
  });

  it('POST /internal/notify rejects a request without the shared secret → 401', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tenantId: 'uid-123', event: 'sale', data: { n: 1 } }),
    }, env);
    expect(res.status).toBe(401);
    expect(notifier.notify).not.toHaveBeenCalled();
  });

  it('POST /internal/notify rejects a wrong shared secret → 401', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Internal-Secret': 'nope' },
      body: JSON.stringify({ tenantId: 'uid-123', event: 'sale' }),
    }, env);
    expect(res.status).toBe(401);
    expect(notifier.notify).not.toHaveBeenCalled();
  });

  it('POST /internal/notify broadcasts a bare sale count (no receipts)', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'uid-123', event: 'sale', data: { count: 3 } }),
    }, env);
    expect(res.status).toBe(200);
    expect(notifier.notify).toHaveBeenCalledWith('uid-123', {
      type: 'sale',
      count: 3,
      tenantId: 'uid-123',
    });
  });

  it('GET /ws without Authorization → 401', async () => {
    const res = await app.request('/ws', {}, env);
    expect(res.status).toBe(401);
  });

  it('GET /ws with invalid token → 401', async () => {
    const res = await app.request('/ws', {
      headers: { Authorization: 'Bearer bogus', Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
  });

  it('GET /ws with a 2-part token (garbage header) → 401', async () => {
    // 'x' alone is invalid base64 → atob throws → tokenAlg null → Firebase path.
    const res = await app.request('/ws', {
      headers: { Authorization: 'Bearer x.y', Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ ok: false, error: 'Invalid token' });
  });

  it('GET /ws with a 2-part token whose header parses without alg → 401', async () => {
    // b64url('{}') = 'e30' — header decodes fine, alg missing → tokenAlg null
    // → Firebase path. Covers the parse-OK / no-alg branch of tokenAlg.
    const res = await app.request('/ws', {
      headers: { Authorization: 'Bearer e30.x', Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ ok: false, error: 'Invalid token' });
  });

  const app = createRealtimeApp({ verifyToken: verifyTokenStub });

  it('GET /ws with valid token + websocket upgrade → routes to DO stub', async () => {
    const res = await app.request('/ws', {
      headers: { Authorization: 'Bearer valid-token', Upgrade: 'websocket' },
    }, env);
    // In production the DO accepts the upgrade and returns 101. In tests we
    // prove routing to the stub — the mock returns 200.
    expect(res.status).toBe(200);
    expect(notifier.fetch).toHaveBeenCalled();
  });

  // ---- session-JWT path (admin-dashboard T09) ----

  const SECRET = 'test-rt-secret';
  const envWithSecret: Env = {
    ...env,
    ADMIN_JWT_SECRET: SECRET,
  };
  const nowS = () => Math.floor(Date.now() / 1000);

  function sessionApp() {
    return createRealtimeApp({ verifyToken: verifyTokenStub });
  }

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

  it('GET /ws with a session JWT + upgrade → routes to the tenant DO stub', async () => {
    const res = await sessionApp().request('/ws', {
      headers: { Authorization: `Bearer ${await mintSession()}`, Upgrade: 'websocket' },
    }, envWithSecret);
    expect(res.status).toBe(200);
    expect(notifierNamespace.idFromName).toHaveBeenCalledWith('uid-123');
    expect(notifier.fetch).toHaveBeenCalled();
  });

  it('GET /ws accepts a session JWT from the ?token= query parameter (no Authorization)', async () => {
    // Browsers cannot set an Authorization header on a WebSocket, so the
    // dashboard puts the session JWT in the query string instead.
    const token = await mintSession();
    const res = await sessionApp().request(
      `/ws?token=${encodeURIComponent(token)}`,
      { headers: { Upgrade: 'websocket' } },
      envWithSecret,
    );
    expect(res.status).toBe(200);
    expect(notifierNamespace.idFromName).toHaveBeenCalledWith('uid-123');
    expect(notifier.fetch).toHaveBeenCalled();
  });

  it('GET /ws rejects 401 when neither a header nor a query token is present', async () => {
    const res = await sessionApp().request('/ws', {
      headers: { Upgrade: 'websocket' },
    }, envWithSecret);
    expect(res.status).toBe(401);
    expect(notifier.fetch).not.toHaveBeenCalled();
  });

  it('GET /ws rejects 401 when the ?token= value is invalid', async () => {
    const res = await sessionApp().request('/ws?token=bogus', {
      headers: { Upgrade: 'websocket' },
    }, envWithSecret);
    expect(res.status).toBe(401);
  });

  it('GET /ws prefers the Authorization header over the query token', async () => {
    const res = await sessionApp().request(`/ws?token=bogus`, {
      headers: { Authorization: `Bearer ${await mintSession()}`, Upgrade: 'websocket' },
    }, envWithSecret);
    expect(res.status).toBe(200);
  });

  it('GET /ws with a session JWT signed by the wrong secret → 401', async () => {
    const token = await mintSessionJwt(
      { tid: 'uid-123', usr: 'admin', role: 'admin', iat: nowS(), exp: nowS() + 3600 },
      'wrong-secret',
    );
    const res = await sessionApp().request('/ws', {
      headers: { Authorization: `Bearer ${token}`, Upgrade: 'websocket' },
    }, envWithSecret);
    expect(res.status).toBe(401);
  });

  it('GET /ws with an expired session JWT → 401', async () => {
    const token = await mintSession({ exp: nowS() - 1 });
    const res = await sessionApp().request('/ws', {
      headers: { Authorization: `Bearer ${token}`, Upgrade: 'websocket' },
    }, envWithSecret);
    expect(res.status).toBe(401);
  });

  it('GET /ws with a valid session JWT but no upgrade header → 426', async () => {
    const res = await sessionApp().request('/ws', {
      headers: { Authorization: `Bearer ${await mintSession()}` },
    }, envWithSecret);
    expect(res.status).toBe(426);
  });
});
