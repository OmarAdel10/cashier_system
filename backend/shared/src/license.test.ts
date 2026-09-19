import { describe, expect, it } from 'vitest';
import { generateKeypair, signLicenseKey, verifyLicenseKey } from './license';
import type { LicensePayload } from './types';

const payload: LicensePayload = {
  tenant_id: 'uid-123',
  device_hwid: 'HW-abc',
  subscription_end: 1_800_000_000_000,
  billing_cycle: 'yearly',
  grace_end: 1_804_320_000_000,
  created_at: 1_700_000_000_000,
};

describe('license Ed25519 signing', () => {
  it('roundtrips: sign then verify with public key', async () => {
    const { privateKeyB64, publicKeyB64 } = generateKeypair();
    const key = await signLicenseKey(payload, privateKeyB64);
    const result = await verifyLicenseKey(key, publicKeyB64);
    expect(result.valid).toBe(true);
    expect(result.payload).toEqual(payload);
  });

  it('rejects a tampered payload byte', async () => {
    const { privateKeyB64, publicKeyB64 } = generateKeypair();
    const key = await signLicenseKey(payload, privateKeyB64);
    // Flip subscription_end inside the payload, re-encode, keep old signature.
    const raw = Buffer.from(
      key.replace(/-/g, '+').replace(/_/g, '/'),
      'base64',
    );
    const sig = raw.subarray(0, 64);
    const json = JSON.parse(raw.subarray(64).toString('utf8')) as LicensePayload;
    json.subscription_end += 1000;
    const forged = Buffer.concat([sig, Buffer.from(JSON.stringify(json), 'utf8')]);
    const forgedKey = forged.toString('base64url');
    const result = await verifyLicenseKey(forgedKey, publicKeyB64);
    expect(result.valid).toBe(false);
  });

  it('rejects a signature from a different keypair', async () => {
    const { privateKeyB64 } = generateKeypair();
    const { publicKeyB64 } = generateKeypair();
    const key = await signLicenseKey(payload, privateKeyB64);
    const result = await verifyLicenseKey(key, publicKeyB64);
    expect(result.valid).toBe(false);
  });

  it('produces base64url key that decodes to 64-byte sig + payload json', async () => {
    const { privateKeyB64 } = generateKeypair();
    const key = await signLicenseKey(payload, privateKeyB64);
    expect(key).toMatch(/^[A-Za-z0-9_-]+$/);
    const raw = Buffer.from(key.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
    expect(raw.length).toBeGreaterThan(64);
    const json = JSON.parse(raw.subarray(64).toString('utf8')) as LicensePayload;
    expect(json.tenant_id).toBe('uid-123');
  });
});
