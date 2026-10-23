/**
 * Paymob webhook runtime wiring integration tests.
 *
 * Verifies that `createPaymobAppFromEnv` correctly wires all dependencies:
 * shared TursoDb, `TursoWebhookEventRepository`, `HmacValidationService`,
 * `LicenseSigningService`, `ProcessWebhookUseCase`, `IssueLicenseUseCase`,
 * and `PostHogAnalyticsService` — and that routes delegate to use cases.
 */
import { describe, expect, it, vi } from 'vitest';
import { createPaymobAppFromEnv } from './runtime';
import type { Env } from './index';

vi.mock('../../shared/src/turso', () => ({
  createTurso: vi.fn(() => ({ exec: vi.fn(), upsertLicense: vi.fn().mockResolvedValue(undefined) })),
}));
vi.mock('../../shared/src/paymob', () => ({
  verifyPaymobHmac: vi.fn((_concatenated, signatureHex, _secret) => signatureHex === 'valid-signature'),
  buildPaymobHmacString: vi.fn((obj: Record<string, unknown>) => JSON.stringify(obj)),
}));
vi.mock('../../shared/src/license', () => ({
  signLicenseKey: vi.fn().mockResolvedValue('signed-license-key-base64'),
}));
vi.mock('./infrastructure/repositories/turso-webhook-event-repository', () => ({
  TursoWebhookEventRepository: class {
    insert = vi.fn().mockResolvedValue(true);
    findByTransactionId = vi.fn().mockResolvedValue(null);
  },
}));

const INTERNAL_SECRET = 'test-hmac-secret';
const PRIVATE_KEY = 'test-private-key-base64';
const PUBLIC_KEY = 'test-public-key-base64';

const env: Env = {
  PAYMOB_HMAC_SECRET: INTERNAL_SECRET,
  ED25519_PRIVATE_KEY: PRIVATE_KEY,
  ED25519_PUBLIC_KEY: PUBLIC_KEY,
  FIREBASE_PROJECT_ID: 'daftari-pos',
  TURSO_DATABASE_URL: 'libsql://test.turso.io',
  TURSO_AUTH_TOKEN: 'test-token',
  POSTHOG_API_KEY: 'test-posthog-key',
};

const webhookPayload = {
  id: 'txn_123',
  success: true,
  isRefunded: false,
  isVoided: false,
  tenantId: 'tenant-1',
  deviceHwid: 'device-abc',
  billingCycle: 'monthly',
  receivedAt: 1_769_000_000_000,
  order: { id: 'order_42', merchant_order_id: 'tenant-1|device-abc|monthly' },
};

const internalHeaders = {
  'Content-Type': 'application/json',
};

describe('runtime wiring — DI integration', () => {
  it('wires ProcessWebhookUseCase into POST /webhook (valid HMAC → license key)', async () => {
    const app = createPaymobAppFromEnv(env);
    const request = new Request('http://localhost/webhook?hmac=valid-signature', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ obj: webhookPayload }),
    });
    const res = await app.fetch(request, env);
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json).toMatchObject({ status: 'success', license_key: expect.any(String) });
  });

  it('rejects request without HMAC secret → 401', async () => {
    const app = createPaymobAppFromEnv({ ...env, PAYMOB_HMAC_SECRET: '' });
    const request = new Request('http://localhost/webhook?hmac=valid-signature', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ obj: webhookPayload }),
    });
    const res = await app.fetch(request, { ...env, PAYMOB_HMAC_SECRET: '' });
    expect(res.status).toBe(401);
  });

  it('rejects invalid HMAC → 401', async () => {
    const app = createPaymobAppFromEnv(env);
    const request = new Request('http://localhost/webhook?hmac=invalid-signature', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ obj: webhookPayload }),
    });
    const res = await app.fetch(request, env);
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json).toEqual({ error: 'INVALID_HMAC' });
  });

  it('rejects invalid JSON → 400', async () => {
    const app = createPaymobAppFromEnv(env);
    const request = new Request('http://localhost/webhook?hmac=valid-signature', {
      method: 'POST',
      headers: internalHeaders,
      body: '{not valid json',
    });
    const res = await app.fetch(request, env);
    expect(res.status).toBe(400);
    const json = await res.json();
    expect(json).toEqual({ error: 'Invalid JSON payload' });
  });

  it('throws when TURSO_DATABASE_URL missing', async () => {
    expect(() => createPaymobAppFromEnv({ ...env, TURSO_DATABASE_URL: '' })).toThrow(
      'Missing required env vars',
    );
  });

  it('throws when TURSO_AUTH_TOKEN missing', async () => {
    expect(() => createPaymobAppFromEnv({ ...env, TURSO_AUTH_TOKEN: '' })).toThrow(
      'Missing required env vars',
    );
  });
});

describe('runtime default export handler', () => {
  it('handles fetch request through default export', async () => {
    const mod = await import('./runtime');
    const handler = mod.default;
    expect(handler).toBeDefined();
    const request = new Request('http://localhost/webhook?hmac=valid-signature', {
      method: 'POST',
      headers: internalHeaders,
      body: JSON.stringify({ obj: webhookPayload }),
    });
    const res = await (handler as any).fetch(request, env, {} as any);
    expect(res.status).toBe(200);
  });
});
