/**
 * Runtime wiring integration tests.
 *
 * Verifies that createRealtimeAppFromEnv correctly wires all dependencies:
 * shared TursoRealtimeTicketRepository, realtime BroadcastService,
 * TicketValidationService, NotifyUseCase, WebSocketConnectUseCase,
 * RateLimiter — and that routes delegate to use cases.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createRealtimeAppFromEnv } from './runtime';
import type { Env } from './index';

vi.mock('../../shared/src/turso', () => ({
  createTurso: vi.fn(() => ({ exec: vi.fn() })),
}));
vi.mock('../../shared/src/infrastructure/repositories/turso-realtime-ticket-repository', () => ({
  TursoRealtimeTicketRepository: vi.fn().mockImplementation(() => ({
    validateAndConsume: vi.fn().mockResolvedValue({ valid: true, tenantId: 'ws-tenant-1' }),
    insert: vi.fn().mockResolvedValue(true),
    sweepExpired: vi.fn().mockResolvedValue(undefined),
  })),
}));

const notifier = {
  notify: vi.fn(async (_tenantId: string, _event: Record<string, unknown>) => undefined),
  fetch: vi.fn(async () => new Response('ok', { status: 200 })),
};

const notifierNamespace = {
  idFromName: vi.fn((name: string) => name),
  get: vi.fn(() => notifier),
};

const env: Env = {
  NOTIFIER: notifierNamespace as unknown as Env['NOTIFIER'],
  ADMIN_JWT_SECRET: 'test-rt-secret',
  INTERNAL_NOTIFY_SECRET: 'test-internal-secret',
  TURSO_DB_URL: 'libsql://test.turso.io',
  TURSO_DB_AUTH_TOKEN: 'test-token',
};

const internalHeaders = {
  'Content-Type': 'application/json',
  'X-Internal-Secret': 'test-internal-secret',
};

describe('runtime wiring — DI integration', () => {
  beforeEach(() => {
    notifier.notify.mockClear();
    notifier.fetch.mockClear();
    notifierNamespace.idFromName.mockClear();
    notifierNamespace.get.mockClear();
  });

  it('wires NotifyUseCase into POST /internal/notify (200 + DO fanout)', async () => {
    const app = createRealtimeAppFromEnv(env);
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'uid-123', event: 'sale', data: { n: 1 } }),
    }, env as unknown as Env);
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json).toMatchObject({ ok: true, broadcastId: expect.any(String) });
    expect(notifierNamespace.idFromName).toHaveBeenCalledWith('uid-123');
    expect(notifier.notify).toHaveBeenCalledWith(
      'uid-123',
      expect.objectContaining({ type: 'sale', tenantId: 'uid-123', data: { n: 1 } }),
    );
  });

  it('wires ticket validation into GET /ws (valid ticket → DO stub)', async () => {
    const app = createRealtimeAppFromEnv(env);
    // The mocked TursoRealtimeTicketRepository returns valid for any ticket,
    // so /ws routes to the DO stub.
    const res = await app.request('/ws?ticket=any-ticket', {
      headers: { Upgrade: 'websocket' },
    }, env as unknown as Env);
    expect(res.status).toBe(200);
    expect(notifier.fetch).toHaveBeenCalled();
    expect(notifierNamespace.idFromName).toHaveBeenCalledWith('ws-tenant-1');
  });

  it('rejects missing secret on /internal/notify → 401', async () => {
    const app = createRealtimeAppFromEnv(env);
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tenantId: 'uid-123', event: 'sale', data: {} }),
    }, env as unknown as Env);
    expect(res.status).toBe(401);
  });

  it('rejects missing ticket on /ws → 401', async () => {
    const app = createRealtimeAppFromEnv(env);
    const res = await app.request('/ws', {}, env as unknown as Env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Missing ticket' });
  });
});
