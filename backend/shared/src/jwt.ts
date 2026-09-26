/**
 * Firebase ID token verification for Cloudflare Workers.
 *
 * Verifies the RS256 signature against Firebase's PUBLIC JWKS endpoint
 * (no secret needed), then checks aud/iss/exp claims. The JWKS is cached
 * in module scope for 1 hour.
 */
import type { FetchFn } from './types';

const JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const JWKS_CACHE_MS = 3_600_000;

interface JwkKey {
  kid?: string;
  kty?: string;
  alg?: string;
  n?: string;
  e?: string;
  [k: string]: unknown;
}

interface JwksCache {
  keys: JwkKey[];
  fetchedAt: number;
}

let jwksCache: JwksCache | null = null;

async function getJwks(fetchFn: FetchFn, noCache?: boolean): Promise<JwkKey[]> {
  if (!noCache && jwksCache && Date.now() - jwksCache.fetchedAt < JWKS_CACHE_MS) {
    return jwksCache.keys;
  }
  const res = await fetchFn(JWKS_URL);
  if (!res.ok) throw new Error(`JWKS fetch failed: ${res.status}`);
  const body = (await res.json()) as { keys?: JwkKey[] };
  const keys = body.keys ?? [];
  jwksCache = { keys, fetchedAt: Date.now() };
  return keys;
}

export interface FirebaseTokenResult {
  valid: boolean;
  uid?: string;
  email?: string;
  /** Firebase sign-in provider id: 'google.com' | 'password' | ... (Admin-SDK
   *  list; the sign-in METHOD string 'emailLink' is NOT a provider id). */
  signInProvider?: string;
  /** Whether the Firebase account email is verified (absent = false). */
  emailVerified?: boolean;
}

function b64urlToJson(part: string): Record<string, unknown> {
  const normalized = part.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return JSON.parse(new TextDecoder().decode(bytes)) as Record<string, unknown>;
}

function b64urlToBytes(part: string): Uint8Array<ArrayBuffer> {
  const normalized = part.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

async function importRsaKey(jwk: JwkKey): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'jwk',
    jwk as unknown as { kty: string; n: string; e: string },
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
}

export async function verifyFirebaseToken(
  token: string,
  projectId: string,
  fetchFn: FetchFn = fetch,
  noCache?: boolean,
): Promise<FirebaseTokenResult> {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return { valid: false };

    const header = b64urlToJson(parts[0]!) as { alg?: string; kid?: string };
    if (header.alg !== 'RS256' || !header.kid) return { valid: false };

    const payload = b64urlToJson(parts[1]!);
    const signature = b64urlToBytes(parts[2]!);

    const keys = await getJwks(fetchFn, noCache);
    const jwk = keys.find((k) => k.kid === header.kid);
    if (!jwk) return { valid: false };

    const key = await importRsaKey(jwk);
    const data = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
    const signatureValid = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      key,
      signature,
      data,
    );
    if (!signatureValid) return { valid: false };

    // Claim checks.
    const now = Math.floor(Date.now() / 1000);
    if (payload.aud !== projectId) return { valid: false };
    if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
      return { valid: false };
    }
    if (typeof payload.exp !== 'number' || payload.exp <= now) return { valid: false };
    if (typeof payload.iat !== 'number' || payload.iat > now) return { valid: false };
    if (typeof payload.sub !== 'string' || payload.sub.length === 0) return { valid: false };

    return {
      valid: true,
      uid: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : undefined,
      signInProvider:
        typeof (payload.firebase as Record<string, unknown> | undefined)?.['sign_in_provider'] ===
        'string'
          ? ((payload.firebase as Record<string, unknown>)['sign_in_provider'] as string)
          : undefined,
      emailVerified: payload.email_verified === true,
    };
  } catch {
    return { valid: false };
  }
}
