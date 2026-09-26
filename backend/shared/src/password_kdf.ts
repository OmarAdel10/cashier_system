/**
 * PBKDF2-HMAC-SHA512 password hashing — scheme-tagged storage:
 *   pbkdf2-sha512$<iterations>$<salt_b64url>$<hash_b64>
 *
 * Byte-compatible with the Dart reference implementation
 * (lib/core/crypto/password_hasher.dart): dkLen 32, hash STANDARD base64
 * (padded, 44 chars), salt base64url (padded or unpadded both accepted).
 * Mirrors the Dart verifier's guards: strict 1,000,000-iteration cap and
 * the 44-char hash-length pre-check (T02 QA acceptance criteria).
 * Verified byte-for-byte against the frozen fixtures generated on the
 * Dart side (backend/shared/fixtures/kdf_vectors.json).
 */
import { b64ToBytes, bytesToB64, bytesToB64url } from './base64';

export interface StoredHash {
  scheme: string;
  iterations: number;
  saltB64Url: string;
  hashB64: string;
}

/** Parses and validates a scheme-tagged stored hash. Null when malformed,
 *  unknown scheme, or iterations out of range (1..1,000,000 inclusive). */
export function parseStored(stored: string): StoredHash | null {
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2-sha512') return null;
  const iterations = Number(parts[1]);
  if (!Number.isInteger(iterations) || iterations <= 0 || iterations > 1_000_000) {
    return null;
  }
  return { scheme: parts[0]!, iterations, saltB64Url: parts[2]!, hashB64: parts[3]! };
}

/** Hashes a password into the scheme-tagged format. Salt is generated
 *  (unpadded base64url, 43 chars for 32 bytes) when omitted.
 *
 *  Default 10,000 iterations: measured 4.7ms/verify native (Node OpenSSL,
 *  same class as workerd BoringSSL) — fits the Workers free 10ms CPU cap
 *  with headroom for the rest of the login route. 50k measured 20.6ms
 *  (over budget). Compensating controls per plan §2.6: login throttling,
 *  optional Turnstile. Iterations are embedded per-hash — raising them
 *  later affects only newly created users, never a migration. */
export async function hashTagged(
  password: string,
  iterations = 10_000,
  saltB64Url?: string,
): Promise<string> {
  const salt = saltB64Url ?? bytesToB64url(crypto.getRandomValues(new Uint8Array(32)));
  return `pbkdf2-sha512$${iterations}$${salt}$${await derive(password, salt, iterations)}`;
}

/** Verifies a password against a scheme-tagged stored hash. */
export async function verifyTagged(stored: string, password: string): Promise<boolean> {
  const parsed = parseStored(stored);
  if (!parsed) return false;
  // dkLen 32 -> 44 standard-base64 chars: reject garbage rows before
  // paying the full derivation cost (mirrors the Dart pre-check).
  if (parsed.hashB64.length !== 44) return false;
  try {
    return fixedTimeEqual(
      await derive(password, parsed.saltB64Url, parsed.iterations),
      parsed.hashB64,
    );
  } catch {
    return false;
  }
}

async function derive(
  password: string,
  saltB64Url: string,
  iterations: number,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(password),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-512', salt: b64ToBytes(saltB64Url), iterations },
    key,
    256,
  );
  return bytesToB64(new Uint8Array(bits));
}

function fixedTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
