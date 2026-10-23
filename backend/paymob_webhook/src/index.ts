/**
 * Paymob Webhook Handler for Daftari POS
 * Cloudflare Worker — TypeScript
 *
 * Verifies the HMAC (SHA-512 over the 20 documented fields, compared with
 * the `hmac` URL query param per Paymob docs), issues real Ed25519 licenses
 * (self-contained keys), and upserts them into Turso.
 *
 * Business logic is delegated to application-layer use cases:
 *   - ProcessWebhookUseCase: HMAC validation, idempotency, entitlement gating,
 *     license payload computation + issue decision
 *   - IssueLicenseUseCase: Ed25519 license-key signing
 *
 * Routes handle HTTP parsing, validation, delegation, and response formatting
 * only — no business logic lives here.
 */
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { buildPaymobHmacString, verifyPaymobHmac } from '../../shared/src/paymob';
import { signLicenseKey } from '../../shared/src/license';
import { createTurso } from '../../shared/src/turso';
import type { LicensePayload, LicenseRecord } from '../../shared/src/types';
import { ProcessWebhookUseCase } from './application/use-cases/process-webhook-use-case';
import { IssueLicenseUseCase } from './application/use-cases/issue-license-use-case';
import { HmacValidationServiceImpl } from './domain/services/hmac-validation-service.impl';
import { LicenseSigningServiceImpl } from './domain/services/license-signing-service.impl';
import { InMemoryWebhookEventRepository } from './infrastructure/repositories/in-memory-webhook-event-repository';

interface Env {
  PAYMOB_HMAC_SECRET: string;
  ED25519_PRIVATE_KEY: string;
  ED25519_PUBLIC_KEY: string;
  FIREBASE_PROJECT_ID: string;
  TURSO_DATABASE_URL: string;
  TURSO_AUTH_TOKEN: string;
  POSTHOG_API_KEY: string;
}

const app = new Hono<{ Bindings: Env }>();

app.use('*', cors());

app.post('/webhook', async (c) => {
  const env = process.env;

  // Fail closed. No secrets configured → cannot validate HMAC or sign licenses.
  if (
    !env.PAYMOB_HMAC_SECRET ||
    env.PAYMOB_HMAC_SECRET.length === 0 ||
    !env.ED25519_PRIVATE_KEY ||
    env.ED25519_PRIVATE_KEY.length === 0
  ) {
    return c.json({ error: 'Worker misconfigured' }, 500);
  }

  const bodyText = await c.req.text();
  const signature = c.req.query('hmac') ?? '';

  let webhook: { obj?: Record<string, unknown> };
  try {
    webhook = JSON.parse(bodyText) as { obj?: Record<string, unknown> };
  } catch {
    return c.json({ error: 'Invalid JSON payload' }, 400);
  }
  const obj = webhook.obj;
  if (!obj) return c.json({ error: 'Missing obj' }, 400);

  // Build the 20-field HMAC concatenated string from the raw obj
  // (route-layer responsibility; uses Paymob's documented field order).
  const concatenated = buildPaymobHmacString(obj);

  // Normalize the raw Paymob webhook body into the domain WebhookEvent shape.
  // Paymob sends: { id, success, is_refunded, is_voided, order: { id, merchant_order_id: 'tenant|device|cycle' } }
  // The domain entity expects camelCase top-level fields.
  const order = obj['order'] as Record<string, unknown> | undefined;
  const merchantOrderId = String(order?.merchant_order_id ?? '');
  const parts = merchantOrderId.split('|');
  const tenantId = parts[0] ?? '';
  const deviceHwid = parts[1] ?? '';
  const billingCycle = (parts[2] ?? 'monthly') as 'monthly' | 'yearly' | 'lifetime';

  const event = {
    transactionId: String(obj.id ?? ''),
    success: obj.success === true,
    isRefunded: obj.is_refunded === true,
    isVoided: obj.is_voided === true,
    tenantId,
    deviceHwid,
    billingCycle,
    receivedAt: Date.now(),
  };

  // Wire use cases with domain service impls + in-memory repo (Phase 3;
  // Phase 4 replaces with Turso-backed repo + DI container).
  const hmacValidationService = new HmacValidationServiceImpl();
  const webhookEventRepo = new InMemoryWebhookEventRepository();
  const licenseSigningService = new LicenseSigningServiceImpl();

  const processUseCase = new ProcessWebhookUseCase(
    hmacValidationService,
    webhookEventRepo,
    licenseSigningService,
  );
  const issueUseCase = new IssueLicenseUseCase(signLicenseKey);

  // Delegate HMAC validation, idempotency, entitlement gating, payload
  // computation, and issue decision to the application-layer use case.
  const processResult = await processUseCase.execute({
    event,
    concatenated,
    signatureHex: signature,
    hmacSecret: env.PAYMOB_HMAC_SECRET,
  });

  if (!processResult.ok) {
    // Map use-case errors to appropriate HTTP status codes.
    const status =
      processResult.error === 'INVALID_HMAC' ? 401 : 400;
    return c.json({ error: processResult.error }, status);
  }

  const { payload, decision } = processResult.data;

  // Only issue a license when the use case decided to issue.
  if (!decision.issue) {
    return c.json({ status: 'ignored', reason: decision.reason ?? 'not issued' });
  }

  // Sign the license payload with Ed25519.
  const licenseResult = await issueUseCase.execute({
    payload,
    privateKeyB64: env.ED25519_PRIVATE_KEY,
  });

  if (!licenseResult.ok) {
    return c.json({ error: licenseResult.error }, 500);
  }

  const licenseKey = licenseResult.data.licenseKey;

  const licenseRecord: LicenseRecord = {
    ...payload,
    licenseKey,
    status: 'active',
  };

  // Upsert into Turso.
  const db = createTurso(env.TURSO_DATABASE_URL, env.TURSO_AUTH_TOKEN);
  await db.upsertLicense(licenseRecord);

  // Fire-and-forget analytics (best-effort; never blocks the response).
  const transactionId = String(obj['id'] ?? '');
  try {
    c.executionCtx?.waitUntil(
      fetch('https://us.i.posthog.com/capture/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          api_key: env.POSTHOG_API_KEY,
          event: 'payment_success',
          distinct_id: payload.tenantId,
          properties: {
            transaction_id: transactionId,
            tenant_id: payload.tenantId,
            device_hwid: payload.deviceHwid,
            billing_cycle: payload.billingCycle,
          },
          timestamp: new Date().toISOString(),
        }),
      }).then((r) => r.body?.cancel()).catch(() => undefined),
    );
  } catch {
    // Analytics failure must not fail the webhook response.
  }

  return c.json({ status: 'success', license_key: licenseKey });
});

export default app;
