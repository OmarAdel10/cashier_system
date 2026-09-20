/**
 * Ed25519 license signing (server-side) and verification (for tests;
 * production verification lives in the Flutter client with the embedded
 * public key).
 *
 * License key format: base64url( sig(64 bytes) || JSON(LicensePayload) )
 * — self-contained: the verifier decodes, splits the 64-byte signature,
 * and verifies the remaining bytes against the public key.
 */
import { ed25519 } from '@noble/curves/ed25519';
import { b64ToBytes, bytesToB64url } from './base64';
import type { LicensePayload } from './types';

export interface Keypair {
  /** 32-byte Ed25519 seed, base64. */
  privateKeyB64: string;
  /** 32-byte raw public point, base64. */
  publicKeyB64: string;
}

export function generateKeypair(): Keypair {
  const privateKey = ed25519.utils.randomPrivateKey();
  const publicKey = ed25519.getPublicKey(privateKey);
  return {
    privateKeyB64: bytesToB64url(privateKey),
    publicKeyB64: bytesToB64url(publicKey),
  };
}

/** Signs the canonical license payload; returns base64url(sig || json). */
export async function signLicenseKey(
  payload: LicensePayload,
  privateKeyB64: string,
): Promise<string> {
  const json = JSON.stringify(payload);
  const message = new TextEncoder().encode(json);
  const signature = ed25519.sign(message, b64ToBytes(privateKeyB64));
  const combined = new Uint8Array(signature.length + message.length);
  combined.set(signature, 0);
  combined.set(message, signature.length);
  return bytesToB64url(combined);
}

export interface VerifyResult {
  valid: boolean;
  payload?: LicensePayload;
}

/** Verifies a self-contained license key against the public key. */
export async function verifyLicenseKey(
  licenseKey: string,
  publicKeyB64: string,
): Promise<VerifyResult> {
  try {
    const raw = b64ToBytes(licenseKey);
    if (raw.length <= 64) return { valid: false };
    const signature = raw.slice(0, 64);
    const message = raw.slice(64);
    const valid = ed25519.verify(signature, message, b64ToBytes(publicKeyB64));
    if (!valid) return { valid: false };
    const payload = JSON.parse(
      new TextDecoder().decode(message),
    ) as unknown as LicensePayload;
    return { valid: true, payload };
  } catch {
    return { valid: false };
  }
}
