import { beforeEach, describe, expect, it, vi } from 'vitest';

import { createRealtimeApp } from '../src/index';
import type { Env } from '../src/index';
import { InMemoryBroadcastRepository } from '../src/infrastructure/repositories/in-memory-broadcast-repository';
import { InMemoryRealtimeTicketRepository } from '../src/infrastructure/repositories/in-memory-realtime-ticket-repository';
import { TicketValidationServiceImpl } from '../src/domain/services/ticket-validation-service.impl';
import { BroadcastServiceImpl } from '../src/domain/services/broadcast-service.impl';

// Test-only: pretend the DO stub is sync-fetch with 101 upgrade.
const notifier = {
  notify: vi.fn(async (_tenantId: string, _event: Record<string, unknown>) => undefined),
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

const ticketRepo = new InMemoryRealtimeTicketRepository();
const broadcastRepo = new InMemoryBroadcastRepository();
const ticketValidationService = new TicketValidationServiceImpl();
const broadcastService = new BroadcastServiceImpl();

const app = createRealtimeApp({
  broadcastService,
  broadcastRepo,
  ticketValidationService,
  ticketRepo,
});

// Seed a valid ticket for /ws tests
beforeEach(async () => {
  notifier.notify.mockClear();
  notifier.fetch.mockClear();
  notifierNamespace.idFromName.mockClear();
  notifierNamespace.get.mockClear();
});

describe('realtime worker routes', () => {
  // ---- POST /internal/notify ----

  it('POST /internal/notify routes to the tenant DO and broadcasts', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'uid-123', event: 'sale', data: { n: 1 } }),
    }, env);
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json).toMatchObject({ ok: true, broadcastId: expect.any(String) });
    expect(notifierNamespace.idFromName).toHaveBeenCalledWith('uid-123');
    expect(notifier.notify).toHaveBeenCalledWith(
      'uid-123',
      expect.objectContaining({ type: 'sale', tenantId: 'uid-123', data: { n: 1 } }),
    );
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
    expect(notifier.notify).toHaveBeenCalledWith('uid-123', expect.objectContaining({
      type: 'sale',
      tenantId: 'uid-123',
      data: { count: 3 },
    }));
  });
  it('POST /internal/notify rejects missing tenantId → 400 MISSING_TENANT', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ event: 'sale', data: { n: 1 } }),
    }, env);
    expect(res.status).toBe(400);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'MISSING_TENANT' });
    expect(notifier.notify).not.toHaveBeenCalled();
  });

  it('POST /internal/notify rejects invalid event → 400 INVALID_EVENT', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'uid-123', event: 'delete_everything', data: {} }),
    }, env);
    expect(res.status).toBe(400);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'INVALID_EVENT' });
    expect(notifier.notify).not.toHaveBeenCalled();
  });

  // ---- Ticket-based WebSocket authentication ----

  it('GET /ws without ticket → 401 Missing ticket', async () => {
    const res = await app.request('/ws', {}, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Missing ticket' });
  });

  it('GET /ws with invalid ticket → 401 Invalid or expired ticket', async () => {
    const res = await app.request('/ws?ticket=invalid-ticket', {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  it('GET /ws with valid ticket → routes to DO stub', async () => {
    await ticketRepo.insert({
      ticket: 'valid-ticket-123',
      tenantId: 'uid-123',
      expiresAt: Date.now() + 60_000,
      createdAt: Date.now(),
    });
    const res = await app.request('/ws?ticket=valid-ticket-123', {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(200);
    expect(notifier.fetch).toHaveBeenCalled();
  });

  it('GET /ws with valid ticket but no upgrade header → 426', async () => {
    await ticketRepo.insert({
      ticket: 'valid-ticket-no-upgrade',
      tenantId: 'uid-123',
      expiresAt: Date.now() + 60_000,
      createdAt: Date.now(),
    });
    const res = await app.request('/ws?ticket=valid-ticket-no-upgrade', {}, env);
    expect(res.status).toBe(426);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Upgrade required' });
  });

  it('GET /ws with expired ticket → 401', async () => {
    await ticketRepo.insert({
      ticket: 'expired-ticket',
      tenantId: 'uid-123',
      expiresAt: 1,
      createdAt: 0,
    });
    const res = await app.request('/ws?ticket=expired-ticket', {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  it('GET /ws with already-used ticket → 401', async () => {
    // The valid ticket gets consumed by the previous test; insert a fresh one then consume it
    await ticketRepo.insert({
      ticket: 'used-ticket',
      tenantId: 'uid-123',
      expiresAt: Date.now() + 60_000,
      createdAt: Date.now(),
    });
    await ticketRepo.validateAndConsume('used-ticket', Date.now());
    const res = await app.request('/ws?ticket=used-ticket', {
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
