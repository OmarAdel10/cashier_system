import { describe, expect, it, vi } from 'vitest';

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

const env: Env = {
  NOTIFIER: notifierNamespace as unknown as Env['NOTIFIER'],
  FIREBASE_PROJECT_ID: 'daftari-pos',
  ADMIN_JWT_SECRET: 'test-rt-secret',
};

const verifyTokenStub = vi.fn(async (token: string) => {
  if (token === 'valid-token') return { valid: true, uid: 'uid-123' };
  return { valid: false };
});

const app = createRealtimeApp({ verifyToken: verifyTokenStub });

describe('realtime worker routes', () => {
  it('POST /internal/notify routes to the tenant DO and broadcasts', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tenantId: 'uid-123', event: 'sale', data: { n: 1 } }),
    }, env);
    expect(res.status).toBe(200);
    expect(notifierNamespace.idFromName).toHaveBeenCalledWith('uid-123');
    expect(notifier.notify).toHaveBeenCalledWith('uid-123', expect.objectContaining({ type: 'sale', n: 1 }));
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
