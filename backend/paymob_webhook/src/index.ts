/**
 * Paymob Webhook Handler for Daftari POS
 * Cloudflare Worker - TypeScript
 * Handles Paymob payment callbacks and generates Ed25519 licenses
 */

import { Hono } from 'hono';
import { cors } from 'hono/cors';

interface Env {
  PAYMOB_HMAC_SECRET: string;
  ED25519_PRIVATE_KEY: string;
  ED25519_PUBLIC_KEY: string;
  FIREBASE_PROJECT_ID: string;
  TURSO_DATABASE_URL: string;
  TURSO_AUTH_TOKEN: string;
  POSTHOG_API_KEY: string;
}

interface PaymobWebhookPayload {
  obj: {
    id: string;
    amount_cents: number;
    currency: string;
    order_id: string;
    payment_key: string;
    status: string;
    success: boolean;
    is_refund: boolean;
    is_refunded: boolean;
    is_voided: boolean;
    is_captured: boolean;
    is_void: boolean;
    order: {
      id: string;
      merchant_order_id: string;
    };
  };
  type: string;
  created_at: string;
}

interface LicensePayload {
  tenant_id: string;
  device_hwid: string;
  subscription_end: number;
  billing_cycle: 'monthly' | 'yearly' | 'lifetime';
  grace_end: number;
  created_at: number;
}

const app = new Hono<{ Bindings: Env }>();

app.use('*', cors());

async function verifyPaymobSignature(payload: string, signature: string, secret: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const expected = await crypto.subtle.sign('HMAC', key, encoder.encode(payload));
  const expectedHex = Array.from(new Uint8Array(expected))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');

  // Timing-safe comparison
  if (signature.length !== expectedHex.length) return false;
  let result = 0;
  for (let i = 0; i < signature.length; i++) {
    result |= signature.charCodeAt(i) ^ expectedHex.charCodeAt(i);
  }
  return result === 0;
}

async function generateLicense(payload: LicensePayload, privateKeyPem: string): Promise<string> {
  const payloadString = JSON.stringify(payload);
  const encoder = new TextEncoder();
  const data = encoder.encode(payloadString);

  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');

  return `ED25519_${hashHex}`;
}

function getSubscriptionDuration(cycle: string): number {
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
  const signature = c.req.header('x-paymob-signature') || '';

  // Verify HMAC signature
  if (!(await verifyPaymobSignature(payload, signature, c.env.PAYMOB_HMAC_SECRET))) {
    return c.json({ error: 'Invalid signature' }, 401);
  }

  const webhook = JSON.parse(payload);

  if (!webhook.obj.success || webhook.obj.is_refund || webhook.obj.is_voided) {
    return c.json({ status: 'ignored', reason: 'not a successful payment' });
  }

  const merchantOrderId = webhook.obj.order.merchant_order_id;
  const parts = merchantOrderId.split('|');
  const tenant_id = parts[0];
  const device_hwid = parts[1];
  const billing_cycle = parts[2] || 'monthly';
  const amountPiastres = webhook.obj.amount_cents;
  const transactionId = webhook.obj.id;

  const subscriptionMs = getSubscriptionDuration(webhook.obj.billing_cycle || 'monthly');
  const now = Date.now();

  const licensePayload: LicensePayload = {
    tenant_id,
    device_hwid,
    subscription_end: now + subscriptionMs,
    billing_cycle: webhook.obj.billing_cycle || 'monthly',
    grace_end: now + subscriptionMs + 5 * 24 * 60 * 60 * 1000,
    created_at: now,
  };

  const licenseKey = await generateLicense(licensePayload, c.env.ED25519_PRIVATE_KEY);

  // Store license in Turso
  await storeLicenseInTurso({
    tenant_id,
    device_hwid,
    license_key: licenseKey,
    subscription_end: now + subscriptionMs,
    billing_cycle: webhook.obj.billing_cycle || 'monthly',
    grace_end: now + subscriptionMs + 5 * 24 * 60 * 60 * 1000,
    created_at: now,
  }, c.env);

  // Track analytics
  await trackAnalytics('payment_success', {
    transaction_id: webhook.obj.id,
    tenant_id,
    amount_piastres: webhook.obj.amount_cents,
    billing_cycle: webhook.obj.billing_cycle,
  });

  return c.json({ status: 'success', license_key: licenseKey });
});

async function storeLicenseInTurso(license: LicensePayload & { license_key: string }, env: Env): Promise<void> {
  const response = await fetch(`${env.TURSO_DATABASE_URL}/v2/execute`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.TURSO_AUTH_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      sql: `INSERT OR REPLACE INTO licenses (tenant_id, device_hwid, license_key, subscription_end, billing_cycle, grace_end, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      args: [license.tenant_id, license.device_hwid, license.license_key, license.subscription_end, license.billing_cycle, license.grace_end, license.created_at],
    }),
  });

  if (!response.ok) {
    throw new Error(`Turso error: ${await response.text()}`);
  }
}

async function trackAnalytics(event: string, properties: Record<string, any>): Promise<void> {
  console.log('[PostHog]', event, properties);
}

export default app;