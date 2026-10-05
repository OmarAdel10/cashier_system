import { beforeEach, describe, expect, it, vi } from 'vitest';

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

const INTERNAL_SECRET = 'test-internal-secret';

const env: Env = {
  NOTIFIER: notifierNamespace as unknown as Env['NOTIFIER'],
  FIREBASE_PROJECT_ID: 'daftari-pos',
  ADMIN_JWT_SECRET: 'test-rt-secret',
  INTERNAL_NOTIFY_SECRET: INTERNAL_SECRET,
  API_URL: 'https://api.example.com',
};

const internalHeaders = {
  'Content-Type': 'application/json',
  'X-Internal-Secret': INTERNAL_SECRET,
};

// Mock fetch for ticket validation
const mockFetch = vi.fn();
global.fetch = mockFetch;

const verifyTokenStub = vi.fn(async (token: string) => {
  if (token === 'valid-token') return { valid: true, uid: 'uid-123' };
  return { valid: false };
});

const app = createRealtimeApp({ verifyToken: verifyTokenStub });

describe('realtime worker routes', () => {
  beforeEach(() => {
    notifier.notify.mockClear();
    notifier.fetch.mockClear();
    mockFetch.mockClear();
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

  // ---- Ticket-based WebSocket authentication ----

  it('GET /ws without ticket → 401 Missing ticket', async () => {
    const res = await app.request('/ws', {}, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Missing ticket' });
  });

  it('GET /ws with invalid ticket → 401 Invalid or expired ticket', async () => {
    mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ ok: false, error: 'Invalid ticket' }), { status: 400 }));
    const res = await app.request('/ws?ticket=invalid-ticket', {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  it('GET /ws with valid ticket → routes to DO stub', async () => {
    const validTicket = 'valid-ticket-123';
    mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ ok: true, data: { tenant_id: 'uid-123' } }), { status: 200 }));
    const res = await app.request(`/ws?ticket=${validTicket}`, {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(200);
    expect(notifier.fetch).toHaveBeenCalled();
    expect(mockFetch).toHaveBeenCalledWith('https://api.example.com/auth/ticket/validate?ticket=valid-ticket-123');
  });

  it('GET /ws with valid ticket but no upgrade header → 426', async () => {
    mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ ok: true, data: { tenant_id: 'uid-123' } }), { status: 200 }));
    const res = await app.request(`/ws?ticket=valid-ticket-123`, {}, env);
    expect(res.status).toBe(426);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Upgrade required' });
  });

  it('GET /ws with expired ticket → 401', async () => {
    mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ ok: false, error: 'Ticket expired' }), { status: 400 }));
    const res = await app.request('/ws?ticket=expired-ticket', {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  it('GET /ws with already-used ticket → 401', async () => {
    mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ ok: false, error: 'Ticket already used' }), { status: 400 }));
    const res = await app.request('/ws?ticket=used-ticket', {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  it('GET /ws with API worker unreachable → 401', async () => {
    mockFetch.mockRejectedValueOnce(new Error('Network error'));
    const res = await app.request('/ws?ticket=valid-ticket', {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  // ---- Old token-based auth should no longer work ----

  it('GET /ws with old-style Authorization header (no ticket) → 401', async () => {
    const res = await app.request('/ws', {
      headers: { Authorization: 'Bearer valid-token', Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Missing ticket' });
  });

  it('GET /ws with old-style ?token= query param (no ticket) → 401', async () => {
    const res = await app.request('/ws?token=some-old-token', {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Missing ticket' });
  });
});
