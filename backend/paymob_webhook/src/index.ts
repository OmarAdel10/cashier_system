/**
 * Paymob Webhook Handler for Daftari POS
 * Cloudflare Worker — TypeScript
 *
 * Verifies the HMAC (SHA-512 over the 20 documented fields, compared with
 * the `hmac` URL query param per Paymob docs), issues real Ed25519 licenses
 * (self-contained keys), and upserts them into Turso.
 */
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { buildPaymobHmacString, verifyPaymobHmac } from '../../shared/src/paymob';
import { signLicenseKey } from '../../shared/src/license';
import { createTurso } from '../../shared/src/turso';
import type { LicensePayload } from '../../shared/src/types';

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

/** Parses `tenant|device_hwid|billing_cycle` from merchant_order_id. */
function parseMerchantOrderId(merchantOrderId: string | null | undefined): {
  tenant_id: string;
  device_hwid: string;
  billing_cycle: 'monthly' | 'yearly' | 'lifetime';
} | null {
  if (!merchantOrderId) return null;
  const parts = merchantOrderId.split('|');
  const tenantId = parts[0] ?? '';
  const deviceHwid = parts[1] ?? '';
  if (tenantId.length === 0 || deviceHwid.length === 0) return null;
  const cycle = (parts[2] ?? 'monthly') as LicensePayload['billing_cycle'];
  const cycleValid = cycle === 'monthly' || cycle === 'yearly' || cycle === 'lifetime';
  return {
    tenant_id: tenantId,
    device_hwid: deviceHwid,
    billing_cycle: cycleValid ? cycle : 'monthly',
  };
}

function subscriptionMs(cycle: LicensePayload['billing_cycle']): number {
  switch (cycle) {
    case 'monthly': return 30 * 24 * 60 * 60 * 1000;
    case 'yearly': return 365 * 24 * 60 * 60 * 1000;
    case 'lifetime': return 0;
    default: return 30 * 24 * 60 * 60 * 1000;
  }
}

app.post('/webhook', async (c) => {
  const env = c.env;
  const payload = await c.req.text();

  // Paymob appends the HMAC to the callback URL query parameters.
  const signature = c.req.query('hmac') ?? '';

  let webhook: { obj?: Record<string, unknown> };
  try {
    webhook = JSON.parse(payload) as { obj?: Record<string, unknown> };
  } catch {
    return c.json({ error: 'Invalid JSON payload' }, 400);
  }
  const obj = webhook.obj;
  if (!obj) return c.json({ error: 'Missing obj' }, 400);

  // Verify HMAC-SHA512 over the 20 documented fields.
  const concatenated = buildPaymobHmacString(obj);
  const hmacValid = await verifyPaymobHmac(concatenated, signature, env.PAYMOB_HMAC_SECRET);
  if (!hmacValid) {
    return c.json({ error: 'Invalid signature' }, 401);
  }

  // Ignore non-successful / refunded / voided transactions.
  const success = obj['success'] === true;
  const isRefunded = obj['is_refunded'] === true;
  const isVoided = obj['is_voided'] === true;
  if (!success || isRefunded || isVoided) {
    return c.json({ status: 'ignored', reason: 'not a successful payment' });
  }

  // tenant|hwid|cycle ride in merchant_order_id.
  const orderId = obj['order'] as { id?: number | string; merchant_order_id?: string | null } | undefined;
  const parsed = parseMerchantOrderId(orderId?.merchant_order_id);
  if (!parsed) {
    return c.json({ error: 'merchant_order_id must be tenant|device_hwid|billing_cycle' }, 422);
  }

  const now = Date.now();
  const subMs = subscriptionMs(parsed.billing_cycle);
  const licensePayload: LicensePayload = {
    tenant_id: parsed.tenant_id,
    device_hwid: parsed.device_hwid,
    subscription_end: parsed.billing_cycle === 'lifetime' ? 0 : now + subMs,
    billing_cycle: parsed.billing_cycle,
    grace_end: parsed.billing_cycle === 'lifetime' ? 0 : now + subMs + 5 * 24 * 60 * 60 * 1000,
    created_at: now,
  };

  const licenseKey = await signLicenseKey(licensePayload, env.ED25519_PRIVATE_KEY);

  // Upsert into Turso.
  const db = createTurso(env.TURSO_DATABASE_URL, env.TURSO_AUTH_TOKEN);
  await db.upsertLicense({
    ...licensePayload,
    license_key: licenseKey,
    status: 'active',
  });

  // Fire-and-forget analytics.
  const transactionId = String(obj['id'] ?? '');
  c.executionCtx.waitUntil(
    fetch('https://us.i.posthog.com/capture/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        api_key: env.POSTHOG_API_KEY,
        event: 'payment_success',
        distinct_id: parsed.tenant_id,
        properties: {
          transaction_id: transactionId,
          tenant_id: parsed.tenant_id,
          device_hwid: parsed.device_hwid,
          billing_cycle: parsed.billing_cycle,
        },
        timestamp: new Date().toISOString(),
      }),
    }).then((r) => r.body?.cancel()).catch(() => undefined),
  );

  return c.json({ status: 'success', license_key: licenseKey });
});

export default app;
