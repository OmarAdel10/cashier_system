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

/** T18 (DAFTARI-92): default PBKDF2 cost for NEW hashes, at the OWASP
 *  PBKDF2-HMAC-SHA512 guidance (210,000). Existing rows keep the iteration
 *  count embedded in their tag and verify forever at that lower cost
 *  (10,000), so raising the default never locks anyone out and needs no
 *  migration. */
export const DEFAULT_ITERATIONS = 210_000;

/** Password policy bounds, shared by the login route and admin user CRUD so
 *  the two surfaces cannot drift. MIN applies to creation/change only
 *  (enforcing it at login would lock out accounts created under an older
 *  policy); MAX is enforced on every surface to bound KDF input work. */
export const MIN_PASSWORD = 12;
export const MAX_PASSWORD = 256;

/** Parses and validates a scheme-tagged stored hash. Null when malformed,
 *  unknown scheme, or iterations out of range (1..1,000,000 inclusive). */
export function parseStored(stored: string): StoredHash | null {
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2-sha512') return null;
  // Strict decimal mirror of Dart's int.tryParse: reject '1e6', '0x10',
  // whitespace, etc. (QA round 1 — exact Dart parity).
  if (!/^\d+$/.test(parts[1]!)) return null;
  const iterations = Number(parts[1]);
  if (!Number.isInteger(iterations) || iterations <= 0 || iterations > 1_000_000) {
    return null;
  }
  return { scheme: parts[0]!, iterations, saltB64Url: parts[2]!, hashB64: parts[3]! };
}

/** Hashes a password into the scheme-tagged format. Salt is generated
 *  (unpadded base64url, 43 chars for 32 bytes) when omitted.
 *
 *  Default cost is DEFAULT_ITERATIONS (210,000, T18). This far exceeds the
 *  original 10,000 chosen to fit the Workers free 10ms CPU cap; the paid CPU
 *  budget plus login throttling (T17) are the compensating controls. The
 *  iteration count is embedded per-hash, so existing rows keep verifying at
 *  10,000 and only newly created users pay the new cost.
 *
 *  Rejects nonsensical inputs (mirrors the Dart ArgumentError guards):
 *  iterations outside 1..1,000,000, and an empty or over-MAX_PASSWORD
 *  password. */
export async function hashTagged(
  password: string,
  iterations = DEFAULT_ITERATIONS,
  saltB64Url?: string,
): Promise<string> {
  if (!Number.isInteger(iterations) || iterations < 1 || iterations > 1_000_000) {
    throw new RangeError(`iterations must be an integer in 1..1000000 (got ${iterations})`);
  }
  if (password.length === 0 || password.length > MAX_PASSWORD) {
    throw new RangeError(`password length must be 1..${MAX_PASSWORD} (got ${password.length})`);
  }
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
