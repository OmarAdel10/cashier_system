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
    is_refund: boolean;
    currency: string;
    amount_cents: number;
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

function verifyPaymobSignature(payload: string, signature: string, secret: string): boolean {
  const crypto = require('crypto');
  const expected = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
}

async function generateLicense(payload: any, privateKeyPem: string): Promise<string> {
  const payloadString = JSON.stringify(payload);
  const encoder = new TextEncoder();
  const data = new TextEncoder().encode(payloadString);
  
  // For now, return a placeholder - in production use @noble/ed25519
  const payloadString2 = JSON.stringify(payload);
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(payloadString2));
  const hashArray = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(payloadString2))));
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

const app = new Hono<{ Bindings: Env }>();
app.use('*', cors());

app.post('/webhook', async (c) => {
  const env = c.env;
  const payload = await c.req.text();
  const signature = c.req.header('x-paymob-signature') || '';
  
  // Verify HMAC signature
  if (!verifyPaymobSignature(payload, signature, c.env.PAYMOB_HMAC_SECRET)) {
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
  
  const payload = {
    tenant_id,
    device_hwid,
    subscription_end: Date.now() + getSubscriptionDuration(webhook.obj.billing_cycle || 'monthly'),
    billing_cycle: webhook.obj.billing_cycle || 'monthly',
    grace_end: Date.now() + getSubscriptionDuration(webhook.obj.billing_cycle || 'monthly') + 5 * 24 * 60 * 60 * 1000,
    created_at: Date.now(),
  };
  
  const licenseKey = await generateLicense(payload, c.env.ED25519_PRIVATE_KEY);
  
  // Store license in Turso
  await storeLicenseInTurso({
    tenant_id,
    device_hwid,
    license_key: licenseKey,
    subscription_end: Date.now() + getSubscriptionDuration(c.env.PAYMOB_HMAC_SECRET || 'monthly'),
    billing_cycle: webhook.obj.billing_cycle || 'monthly',
    grace_end: Date.now() + getSubscriptionDuration(webhook.obj.billing_cycle || 'monthly') + 5 * 24 * 60 * 60 * 1000,
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

function getSubscriptionDuration(cycle: string): number {
  switch (cycle) {
    case 'monthly': return 30 * 24 * 60 * 60 * 1000;
    case 'yearly': return 365 * 24 * 60 * 60 * 1000;
    case 'lifetime': return 0;
    default: return 30 * 24 * 60 * 60 * 1000;
  }
}

async function storeLicenseInTurso(license: any, env: any): Promise<void> {
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

function verifyPaymobSignature(payload: string, signature: string, secret: string): boolean {
  const crypto = require('crypto');
  const expected = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
}

export default app;
