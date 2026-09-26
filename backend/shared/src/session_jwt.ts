/**
 * HS256 session JWT minted by daftari-api when an admin logs in with
 * username/password; verified by every authenticated route (dual-token
 * middleware) and by the realtime worker's /ws upgrade. Symmetric —
 * ADMIN_JWT_SECRET must be identical on api + realtime within an env.
 *
 * Claims use SECONDS (JWT convention): expiry check is exp * 1000 <= now.
 */
import { b64urlToJson, bytesToB64url } from './base64';

export interface SessionClaims {
  /** Tenant id (owner's Firebase UID). */
  tid: string;
  /** The admin account's username. */
  usr: string;
  /** 'admin' — dashboard logins are admin-role only. */
  role: string;
  iat: number;
  exp: number;
}

const te = new TextEncoder();

function b64urlJson(value: unknown): string {
  return bytesToB64url(te.encode(JSON.stringify(value)));
}

async function hmac(secret: string, data: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    te.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return bytesToB64url(new Uint8Array(await crypto.subtle.sign('HMAC', key, te.encode(data))));
}

export async function mintSessionJwt(
  claims: SessionClaims,
  secret: string,
): Promise<string> {
  const data = `${b64urlJson({ alg: 'HS256', typ: 'JWT' })}.${b64urlJson(claims)}`;
  return `${data}.${await hmac(secret, data)}`;
}

export async function verifySessionJwt(
  token: string,
  secret: string,
): Promise<SessionClaims | null> {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    const expected = await hmac(secret, `${parts[0]!}.${parts[1]!}`);
    if (!fixedTimeEqual(expected, parts[2]!)) return null;
    const claims = b64urlToJson(parts[1]!) as unknown as SessionClaims;
    if (typeof claims.exp !== 'number' || claims.exp * 1000 <= Date.now()) return null;
    if (!claims.tid || !claims.usr || !claims.role) return null;
    return claims;
  } catch {
    return null;
  }
}

function fixedTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
