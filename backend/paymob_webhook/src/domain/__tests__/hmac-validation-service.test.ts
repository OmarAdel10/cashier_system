/**
 * Unit tests for HmacValidationServiceImpl.
 *
 * Delegates to shared `verifyPaymobHmac`. Tests verify delegation works
 * with real HMAC-SHA512 signatures computed via Web Crypto API
 * (available in both Node and Cloudflare Workers).
 */
import { describe, expect, it } from 'vitest';
import { HmacValidationServiceImpl } from '../services/hmac-validation-service.impl';

const SECRET = 'paymob_hmac_secret_12345';

async function sign(concatenated: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(SECRET),
    { name: 'HMAC', hash: 'SHA-512' },
    false,
    ['sign'],
  );
  const sigBuf = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(concatenated));
  return Array.from(new Uint8Array(sigBuf))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

describe('HmacValidationServiceImpl', () => {
  const svc = new HmacValidationServiceImpl();

  it('returns true for valid HMAC', async () => {
    const concatenated =
      'amount_cents1000created_at1769000000currencyUSDerror_occuredfalsehas_parent_transactionfalseidtxn_123integration_idint_123is_3d_securefalseis_authfalseis_capturefalseis_refundedfalseis_standalone_paymentfalseis_voidedfalseorder.idorder_42ownerowner_1pendingfalsesource_data.pansource_data.sub_typecard_source_data.typecard_successtrue';
    const signature = await sign(concatenated);
    const result = await svc.isValid(concatenated, signature, SECRET);
    expect(result).toBe(true);
  });

  it('returns false for invalid HMAC signature', async () => {
    const result = await svc.isValid('some-concatenated-string', 'deadbeef', SECRET);
    expect(result).toBe(false);
  });

  it('returns false for wrong secret', async () => {
    const concatenated = 'some-concatenated-string';
    const signature = await sign(concatenated);
    const result = await svc.isValid(concatenated, signature, 'wrong-secret');
    expect(result).toBe(false);
  });

  it('returns false for empty inputs', async () => {
    const result = await svc.isValid('', '', '');
    expect(result).toBe(false);
  });
});
