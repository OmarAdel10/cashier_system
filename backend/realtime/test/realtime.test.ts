import { beforeEach, describe, expect, it, vi } from 'vitest';

import { createRealtimeApp } from '../src/index';
import type { Env } from '../src/index';
import { RateLimiter } from '../src/infrastructure/services/rate-limiter';
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
const JWT_SECRET = 'test-rt-secret';

const env: Env = {
  NOTIFIER: notifierNamespace as unknown as Env['NOTIFIER'],
  ADMIN_JWT_SECRET: JWT_SECRET,
  INTERNAL_NOTIFY_SECRET: INTERNAL_SECRET,
  TURSO_DB_URL: 'libsql://test.turso.io',
  TURSO_DB_AUTH_TOKEN: 'test-token',
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

// Strict rate limiter for rate-limit tests (1 request per minute).
const rateLimiterApp = createRealtimeApp({
  broadcastService,
  broadcastRepo,
  ticketValidationService,
  ticketRepo,
  rateLimiter: new RateLimiter(1, 60_000),
});

function b64urlEncode(obj: unknown): string {
  const json = JSON.stringify(obj);
  const bytes = new TextEncoder().encode(json);
  let binary = '';
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]!);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function makeTestJwt(
  secret: string,
  payload: Record<string, unknown>,
): Promise<string> {
  const fullPayload = {
    aud: 'realtime',
    iss: 'daftari-realtime',
    ...payload,
  };
  const header = b64urlEncode({ alg: 'HS256', typ: 'JWT' });
  const payloadB64 = b64urlEncode(fullPayload);
  const data = new TextEncoder().encode(`${header}.${payloadB64}`);
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, data);
  const sigBytes = new Uint8Array(sig);
  let sigBinary = '';
  for (let i = 0; i < sigBytes.length; i += 1) {
    sigBinary += String.fromCharCode(sigBytes[i]!);
  }
  const sigB64 = btoa(sigBinary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${header}.${payloadB64}.${sigB64}`;
}

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

  it('POST /internal/notify accepts session_revoked event → 200', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'uid-123', event: 'session_revoked', data: {} }),
    }, env);
    expect(res.status).toBe(200);
    expect(notifier.notify).toHaveBeenCalled();
  });

  it('POST /internal/notify rejects oversized body → 413', async () => {
    const bigData = { payload: 'x'.repeat(300_000) };
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: { ...internalHeaders },
      body: JSON.stringify({ tenantId: 'uid-123', event: 'sale', data: bigData }),
    }, env);
    expect(res.status).toBe(413);
    expect(notifier.notify).not.toHaveBeenCalled();
  });

  it('POST /internal/notify rate limits excessive requests → 429', async () => {
    // First request allowed
    const res1 = await rateLimiterApp.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'tenant-rl', event: 'sale', data: {} }),
    }, env);
    expect(res1.status).toBe(200);
    // Second request within window → 429
    const res2 = await rateLimiterApp.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'tenant-rl', event: 'sale', data: {} }),
    }, env);
    expect(res2.status).toBe(429);
    const json = (await res2.json()) as { ok: boolean; error: string; retryAfterMs?: number };
    expect(json).toMatchObject({ ok: false, error: 'RATE_LIMITED' });
    expect(json.retryAfterMs).toBeGreaterThan(0);
  });

  it('POST /internal/notify rate limit is global (different tenantIds share quota) → 429', async () => {
    // Exhaust quota with tenant-a
    await rateLimiterApp.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'tenant-a', event: 'sale', data: {} }),
    }, env);
    // tenant-b gets 429 because quota is global
    const res = await rateLimiterApp.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'tenant-b', event: 'sale', data: {} }),
    }, env);
    expect(res.status).toBe(429);
  });

  it('POST /internal/notify sanitizes prototype-pollution keys in data → 200', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({
        tenantId: 'uid-123',
        event: 'sale',
        data: { __proto__: { polluted: true }, count: 1 },
      }),
    }, env);
    expect(res.status).toBe(200);
    expect(notifier.notify).toHaveBeenCalledTimes(1);
    const callArgs = notifier.notify.mock.calls[0] as [string, Record<string, unknown>];
    expect(callArgs[0]).toBe('uid-123');
    expect(callArgs[1].data).toEqual({ count: 1 });
    expect(callArgs[1].data).not.toHaveProperty('__proto__');
  });

  it('POST /internal/notify rejects non-string event → 400 INVALID_EVENT', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'uid-123', event: 123, data: {} }),
    }, env);
    expect(res.status).toBe(400);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'INVALID_EVENT' });
  });

  it('POST /internal/notify with non-object data → 200 (data coerced to undefined)', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'uid-123', event: 'sale', data: 'not-an-object' }),
    }, env);
    expect(res.status).toBe(200);
    expect(notifier.notify).toHaveBeenCalled();
  });

  it('GET /ws rate limits excessive requests → 429', async () => {
    await ticketRepo.insert({
      ticket: 'ws-rl-ticket',
      tenantId: 'uid-rl',
      expiresAt: Date.now() + 60_000,
      createdAt: Date.now(),
    });
    // First request allowed
    const res1 = await rateLimiterApp.request('/ws?ticket=ws-rl-ticket', {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res1.status).toBe(200);
    // Second request within window → 429
    const res2 = await rateLimiterApp.request('/ws?ticket=ws-rl-ticket', {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res2.status).toBe(429);
  });

  it('POST /internal/notify fan-out failure → 503 BROADCAST_FANOUT_FAILED', async () => {
    notifier.notify.mockRejectedValueOnce(new Error('DO down'));
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ tenantId: 'uid-123', event: 'sale', data: { n: 1 } }),
    }, env);
    expect(res.status).toBe(503);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'BROADCAST_FANOUT_FAILED' });
  });

  it('POST /internal/notify rejects invalid JSON → 400', async () => {
    const res = await app.request('/internal/notify', {
      method: 'POST',
      headers: { ...internalHeaders, 'Content-Type': 'application/json' },
      body: '{not valid json',
    }, env);
    expect(res.status).toBe(400);
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

  it('GET /ws with valid ticket but no upgrade header → 426 (ticket not consumed)', async () => {
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
    // Ticket must still be valid (not consumed) since upgrade was checked first
    const res2 = await app.request('/ws?ticket=valid-ticket-no-upgrade', {
      headers: { Upgrade: 'websocket' },
    }, env);
    expect(res2.status).toBe(200);
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

  // ---- Bearer JWT WebSocket authentication (spec: PRD.md /ws auth) ----

  it('GET /ws with valid Bearer JWT → routes to DO stub', async () => {
    const token = await makeTestJwt(JWT_SECRET, { tenantId: 'uid-456' });
    const res = await app.request('/ws', {
      headers: { Authorization: `Bearer ${token}`, Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(200);
    expect(notifier.fetch).toHaveBeenCalled();
    expect(notifierNamespace.idFromName).toHaveBeenCalledWith('uid-456');
  });

  it('GET /ws with invalid Bearer JWT → 401', async () => {
    const res = await app.request('/ws', {
      headers: { Authorization: 'Bearer not-a-jwt', Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  it('GET /ws with wrong-secret Bearer JWT → 401', async () => {
    const token = await makeTestJwt('wrong-secret', { tenantId: 'uid-456' });
    const res = await app.request('/ws', {
      headers: { Authorization: `Bearer ${token}`, Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  // ---- JWT security: exp / nbf / aud / iss ----

  it('GET /ws with expired JWT (exp in past) → 401', async () => {
    const nowSec = Math.floor(Date.now() / 1000);
    const token = await makeTestJwt(JWT_SECRET, {
      tenantId: 'uid-456',
      exp: nowSec - 100,
    });
    const res = await app.request('/ws', {
      headers: { Authorization: `Bearer ${token}`, Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  it('GET /ws with not-yet-valid JWT (nbf in future) → 401', async () => {
    const nowSec = Math.floor(Date.now() / 1000);
    const token = await makeTestJwt(JWT_SECRET, {
      tenantId: 'uid-456',
      nbf: nowSec + 100,
    });
    const res = await app.request('/ws', {
      headers: { Authorization: `Bearer ${token}`, Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  it('GET /ws with wrong aud → 401', async () => {
    const token = await makeTestJwt(JWT_SECRET, {
      tenantId: 'uid-456',
      aud: 'other-service',
    });
    const res = await app.request('/ws', {
      headers: { Authorization: `Bearer ${token}`, Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  it('GET /ws with wrong iss → 401', async () => {
    const token = await makeTestJwt(JWT_SECRET, {
      tenantId: 'uid-456',
      iss: 'other-service',
    });
    const res = await app.request('/ws', {
      headers: { Authorization: `Bearer ${token}`, Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  it('GET /ws with JWT tenantId invalid format → 401', async () => {
    const token = await makeTestJwt(JWT_SECRET, {
      tenantId: 'Invalid Tenant!',
    });
    const res = await app.request('/ws', {
      headers: { Authorization: `Bearer ${token}`, Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  it('GET /ws with malformed JWT payload (triggers verify catch) → 401', async () => {
    const header = b64urlEncode({ alg: 'HS256' });
    const badPayloadB64 = btoa('{not valid json')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
    const data = new TextEncoder().encode(`${header}.${badPayloadB64}`);
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(JWT_SECRET),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const sig = await crypto.subtle.sign('HMAC', key, data);
    const sigBytes = new Uint8Array(sig);
    let sigBinary = '';
    for (let i = 0; i < sigBytes.length; i += 1) {
      sigBinary += String.fromCharCode(sigBytes[i]!);
    }
    const sigB64 = btoa(sigBinary)
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
    const token = `${header}.${badPayloadB64}.${sigB64}`;
    const res = await app.request('/ws', {
      headers: { Authorization: `Bearer ${token}`, Upgrade: 'websocket' },
    }, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ ok: false, error: 'Invalid or expired ticket' });
  });

  // ---- In-memory repository coverage (temporary, Phase 4 replaces with Turso) ----

  it('InMemoryBroadcastRepository.getRecentForTenant returns newest first', async () => {
    const now = Date.now();
    await broadcastRepo.insert({ id: 'bc-1', tenantId: 't1', type: 'sale', data: {}, createdAt: now - 2000 });
    await broadcastRepo.insert({ id: 'bc-2', tenantId: 't1', type: 'session', data: {}, createdAt: now - 1000 });
    await broadcastRepo.insert({ id: 'bc-3', tenantId: 't2', type: 'sale', data: {}, createdAt: now });

    const recent = await broadcastRepo.getRecentForTenant('t1', 5);
    expect(recent).toHaveLength(2);
    expect(recent[0]!.id).toBe('bc-2');
    expect(recent[1]!.id).toBe('bc-1');

    const limited = await broadcastRepo.getRecentForTenant('t1', 1);
    expect(limited).toHaveLength(1);
    expect(limited[0]!.id).toBe('bc-2');

    const empty = await broadcastRepo.getRecentForTenant('nonexistent', 5);
    expect(empty).toHaveLength(0);
  });

  it('InMemoryRealtimeTicketRepository.sweepExpired removes expired tickets', async () => {
    const now = Date.now();
    await ticketRepo.insert({
      ticket: 'expired-soon',
      tenantId: 't1',
      expiresAt: now - 1000,
      createdAt: now - 2000,
    });
    await ticketRepo.insert({
      ticket: 'still-valid',
      tenantId: 't1',
      expiresAt: now + 60_000,
      createdAt: now,
    });

    await ticketRepo.sweepExpired(now);

    // Expired ticket is gone
    const expired = await ticketRepo.validateAndConsume('expired-soon', now);
    expect(expired).toEqual({ valid: false, error: 'INVALID_TICKET' });

    // Valid ticket still works
    const valid = await ticketRepo.validateAndConsume('still-valid', now);
    expect(valid).toEqual({ valid: true, tenantId: 't1' });
  });
});
