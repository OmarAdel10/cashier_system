import { describe, expect, it, vi } from 'vitest';

vi.mock('@libsql/client', () => ({
  createClient: () => ({ execute: async () => ({ rows: [], columns: [], rowsAffected: 0 }) }),
}));

import { createRealtimeApp } from '../src/index';
import type { Env } from '../src/index';

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
});
