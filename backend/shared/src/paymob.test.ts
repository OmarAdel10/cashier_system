import { describe, expect, it } from 'vitest';
import { buildPaymobHmacString, verifyPaymobHmac } from './paymob';

// Sample transaction processed callback from Paymob docs (June 2026).
// Expected concatenated string verified against the docs sample:
// 1000002024-06-13T11:33:44.592345EGPfalsefalse1920364654097558truefalse
// falsefalsetruefalse217503754302852false2346MasterCardcardtrue
const sampleObj = {
  id: 192036465,
  pending: false,
  amount_cents: 100000,
  success: true,
  is_auth: false,
  is_capture: false,
  is_standalone_payment: true,
  is_voided: false,
  is_refunded: false,
  is_3d_secure: true,
  integration_id: 4097558,
  has_parent_transaction: false,
  order: { id: 217503754 },
  created_at: '2024-06-13T11:33:44.592345',
  currency: 'EGP',
  source_data: { pan: '2346', type: 'card', sub_type: 'MasterCard' },
  error_occured: false,
  owner: 302852,
};

describe('buildPaymobHmacString', () => {
  it('concatenates the 20 documented fields in lexicographic order', () => {
    const s = buildPaymobHmacString(sampleObj);
    expect(s).toBe(
      '1000002024-06-13T11:33:44.592345EGPfalsefalse1920364654097558'
        + 'truefalsefalsefalsetruefalse217503754302852false2346MasterCardcardtrue',
    );
  });

  it('renders missing fields as empty string', () => {
    const s = buildPaymobHmacString({
      ...sampleObj,
      source_data: { pan: null, type: null, sub_type: null },
    } as unknown as Record<string, unknown>);
    expect(s).toBe(
      '1000002024-06-13T11:33:44.592345EGPfalsefalse1920364654097558'
        + 'truefalsefalsefalsetruefalse217503754302852falsetrue',
    );
  });

  it('renders booleans as true/false and numbers as plain digits', () => {
    const s = buildPaymobHmacString({ ...sampleObj, success: false } as unknown as Record<string, unknown>);
    expect(s.endsWith('cardfalse')).toBe(true);
  });
});

describe('verifyPaymobHmac', () => {
  const secret = 'test-hmac-secret';

  it('accepts a valid HMAC-SHA512 hex from the docs algorithm', async () => {
    const concat = buildPaymobHmacString(sampleObj);
    // Compute expected HMAC-SHA512 with Web Crypto (Node has it natively).
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-512' },
      false,
      ['sign'],
    );
    const sigBuf = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(concat));
    const expected = Array.from(new Uint8Array(sigBuf))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');

    await expect(verifyPaymobHmac(concat, expected, secret)).resolves.toBe(true);
  });

  it('rejects a tampered signature', async () => {
    const concat = buildPaymobHmacString(sampleObj);
    await expect(verifyPaymobHmac(concat, 'deadbeef'.repeat(16), secret)).resolves.toBe(false);
  });

  it('rejects when lengths differ without throwing', async () => {
    const concat = buildPaymobHmacString(sampleObj);
    await expect(verifyPaymobHmac(concat, 'abc', secret)).resolves.toBe(false);
  });

  it('is case-insensitive on hex casing', async () => {
    const concat = buildPaymobHmacString(sampleObj);
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-512' },
      false,
      ['sign'],
    );
    const sigBuf = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(concat));
    const upper = Array.from(new Uint8Array(sigBuf))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('')
      .toUpperCase();

    await expect(verifyPaymobHmac(concat, upper, secret)).resolves.toBe(true);
  });
});
