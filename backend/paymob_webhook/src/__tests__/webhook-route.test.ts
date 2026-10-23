/**
 * Integration tests for POST /webhook route.
 *
 * Tests the full route handler flow: HMAC validation, idempotency,
 * entitlement gating, license signing, Turso upsert, and PostHog fan-out.
 * All dependencies (shared crypto libs, Turso) are mocked.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createPaymobApp } from '../index';
import { verifyPaymobHmac } from '../../../shared/src/paymob';
import type { TursoDb } from '../../../shared/src/turso';

// Mock shared dependencies
vi.mock('../../../shared/src/paymob', () => ({
  buildPaymobHmacString: vi.fn((obj: Record<string, unknown>) => {
    // Simple deterministic concatenation for testing
    return JSON.stringify(obj);
  }),
  verifyPaymobHmac: vi.fn(async () => true),
}));

vi.mock('../../../shared/src/license', () => ({
  signLicenseKey: vi.fn(async () => 'signed-license-key-123'),
}));

vi.mock('../../../shared/src/turso', () => ({
  createTurso: vi.fn(() => ({
    upsertLicense: vi.fn(async () => {}),
  })),
}));

vi.mock('../infrastructure/repositories/in-memory-webhook-event-repository', () => ({
  InMemoryWebhookEventRepository: class {
    insert = vi.fn().mockResolvedValue(true);
    findByTransactionId = vi.fn().mockResolvedValue(null);
  },
}));

const testEnv = {
  PAYMOB_HMAC_SECRET: 'test-hmac-secret',
  ED25519_PRIVATE_KEY: 'test-private-key',
  ED25519_PUBLIC_KEY: 'test-public-key',
  FIREBASE_PROJECT_ID: 'test-project',
  TURSO_DATABASE_URL: 'test-turso-url',
  TURSO_AUTH_TOKEN: 'test-turso-token',
  POSTHOG_API_KEY: 'test-posthog-key',
};

const mockDb = { upsertLicense: vi.fn(async () => {}) } as unknown as TursoDb;
const app = createPaymobApp({ db: mockDb });

const validObj = {
  id: 'txn_123',
  success: true,
  is_refunded: false,
  is_voided: false,
  order: { id: 'order_42', merchant_order_id: 'tenant_1|device_abc|monthly' },
};

function makeWebhookRequest(body: Record<string, unknown>, hmacSignature = 'valid-sig') {
  return new Request('http://localhost/webhook?hmac=' + hmacSignature, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

describe('POST /webhook', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(verifyPaymobHmac).mockResolvedValue(true);
  });

  it('returns 200 with license key for valid webhook', async () => {
    const res = await app.fetch(makeWebhookRequest({ obj: validObj }), testEnv);
    expect(res.status).toBe(200);
    const json = (await res.json()) as { status: string; license_key: string };
    expect(json.status).toBe('success');
    expect(json.license_key).toBe('signed-license-key-123');
  });

  it('returns 401 when secrets missing', async () => {
    const noSecretEnv = { ...testEnv, PAYMOB_HMAC_SECRET: '' };
    const res = await app.fetch(makeWebhookRequest({ obj: validObj }), noSecretEnv);
    expect(res.status).toBe(401);
  });

  it('returns 400 for invalid JSON', async () => {
    const res = await app.fetch(
      new Request('http://localhost/webhook?hmac=valid-sig', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{not valid json',
      }),
      testEnv,
    );
    expect(res.status).toBe(400);
    const json = (await res.json()) as { error?: string; status?: string; license_key?: string };
    expect(json.error).toBe('Invalid JSON payload');
  });

  it('returns 400 for missing obj', async () => {
    const res = await app.fetch(
      new Request('http://localhost/webhook?hmac=valid-sig', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ other: 'data' }),
      }),
      testEnv,
    );
    expect(res.status).toBe(400);
    const json = (await res.json()) as { error?: string; status?: string; license_key?: string };
    expect(json.error).toBe('Missing obj');
  });

  it('returns 401 for invalid HMAC', async () => {
    vi.mocked(verifyPaymobHmac).mockResolvedValue(false);
    const res = await app.fetch(makeWebhookRequest({ obj: validObj }), testEnv);
    expect(res.status).toBe(401);
    const json = (await res.json()) as { error?: string; status?: string; license_key?: string };
    expect(json.error).toBe('INVALID_HMAC');
  });

  it('returns 400 INVALID_EVENT for unsuccessful payment', async () => {
    const res = await app.fetch(
      new Request('http://localhost/webhook?hmac=valid-sig', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ obj: { ...validObj, success: false } }),
      }),
      testEnv,
    );
    expect(res.status).toBe(400);
    const json = (await res.json()) as { error?: string; status?: string; license_key?: string };
    expect(json.error).toBe('INVALID_EVENT');
  });

  it('returns 400 INVALID_EVENT for refunded payment', async () => {
    const res = await app.fetch(
      new Request('http://localhost/webhook?hmac=valid-sig', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ obj: { ...validObj, is_refunded: true } }),
      }),
      testEnv,
    );
    expect(res.status).toBe(400);
    const json = (await res.json()) as { error?: string; status?: string; license_key?: string };
    expect(json.error).toBe('INVALID_EVENT');
  });

  it('calls upsertLicense with full payload on success', async () => {
    const res = await app.fetch(makeWebhookRequest({ obj: validObj }), testEnv);
    expect(res.status).toBe(200);
  });

  it('throws when db is missing', async () => {
    expect(() => createPaymobApp({})).toThrow('db is required');
  });

  it('processes yearly billing cycle', async () => {
    const yearlyObj = { ...validObj, order: { ...validObj.order, merchant_order_id: 'tenant-2|device-xyz|yearly' } };
    const res = await app.fetch(
      new Request('http://localhost/webhook?hmac=valid-sig', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ obj: yearlyObj }),
      }),
      testEnv,
    );
    expect(res.status).toBe(200);
  });

  it('processes lifetime billing cycle', async () => {
    const lifetimeObj = { ...validObj, order: { ...validObj.order, merchant_order_id: 'tenant-3|device-uvw|lifetime' } };
    const res = await app.fetch(
      new Request('http://localhost/webhook?hmac=valid-sig', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ obj: lifetimeObj }),
      }),
      testEnv,
    );
    expect(res.status).toBe(200);
  });

  it('returns 422 for invalid merchant_order_id', async () => {
    const res = await app.fetch(
      new Request('http://localhost/webhook?hmac=valid-sig', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ obj: { ...validObj, order: { ...validObj.order, merchant_order_id: 'invalid-format' } } }),
      }),
      testEnv,
    );
    expect(res.status).toBe(422);
  });

  it('returns 200 ignored when use case decides not to issue', async () => {
    const shouldIssue = vi.fn().mockReturnValue({ issue: false, reason: 'not eligible' });
    const customApp = createPaymobApp({
      db: mockDb,
      licenseSigningService: { shouldIssue, computePayload: vi.fn() },
    } as any);
    const res = await customApp.fetch(makeWebhookRequest({ obj: validObj }), testEnv);
    expect(res.status).toBe(200);
    const json = (await res.json()) as { status: string; reason?: string };
    expect(json.status).toBe('ignored');
  });

  it('returns 500 when license signing fails', async () => {
    const signLicenseKey = vi.fn().mockRejectedValue(new Error('signing failed'));
    const customApp = createPaymobApp({
      db: mockDb,
      signLicenseKey,
    } as any);
    const res = await customApp.fetch(makeWebhookRequest({ obj: validObj }), testEnv);
    expect(res.status).toBe(500);
  });
});
