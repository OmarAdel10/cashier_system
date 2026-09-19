import { describe, expect, it } from 'vitest';
import { createHash, generateKeyPairSync, sign as rsaSign } from 'node:crypto';
import { verifyFirebaseToken } from './jwt';

const PROJECT_ID = 'daftari-pos';

/** Test-only RSA keypair + JWKS server simulation. */
const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const PUBLIC_JWK = publicKey.export({ format: 'jwk' }) as Record<string, string>;
const KID = 'test-key-1';

const jwksResponse = () =>
  Promise.resolve(
    new Response(JSON.stringify({ keys: [{ ...PUBLIC_JWK, kid: KID, alg: 'RS256' }] }), {
      status: 200,
    }),
  );

function b64url(input: string | Uint8Array): string {
  const buf = typeof input === 'string' ? Buffer.from(input, 'utf8') : Buffer.from(input);
  return buf.toString('base64url');
}

/** Forges a Firebase-style RS256 ID token. */
function forgeToken(claims: Record<string, unknown>, kid = KID): string {
  const header = b64url(JSON.stringify({ alg: 'RS256', kid }));
  const payload = b64url(JSON.stringify(claims));
  const data = `${header}.${payload}`;
  const signature = rsaSign('RSA-SHA256', Buffer.from(data), privateKey);
  return `${data}.${b64url(new Uint8Array(signature))}`;
}

const validClaims = () => {
  const now = Math.floor(Date.now() / 1000);
  return {
    aud: PROJECT_ID,
    iss: `https://securetoken.google.com/${PROJECT_ID}`,
    sub: 'uid-123',
    email: 'owner@daftari.co',
    exp: now + 3600,
    iat: now,
    auth_time: now,
    firebase: { identities: {}, sign_in_provider: 'password' },
  };
};

describe('verifyFirebaseToken', () => {
  it('accepts a valid token and extracts uid + email', async () => {
    const token = forgeToken(validClaims());
    const result = await verifyFirebaseToken(token, PROJECT_ID, jwksResponse);
    expect(result.valid).toBe(true);
    expect(result.uid).toBe('uid-123');
    expect(result.email).toBe('owner@daftari.co');
  });

  it('rejects a token signed for a different project (aud mismatch)', async () => {
    const token = forgeToken({ ...validClaims(), aud: 'other-project' });
    const result = await verifyFirebaseToken(token, PROJECT_ID, jwksResponse);
    expect(result.valid).toBe(false);
  });

  it('rejects an expired token', async () => {
    const claims = validClaims();
    claims.exp = Math.floor(Date.now() / 1000) - 10;
    const token = forgeToken(claims);
    const result = await verifyFirebaseToken(token, PROJECT_ID, jwksResponse);
    expect(result.valid).toBe(false);
  });

  it('rejects a tampered payload (signature mismatch)', async () => {
    const token = forgeToken(validClaims());
    const parts = token.split('.');
    const payload = JSON.parse(Buffer.from(parts[1]!, 'base64url').toString('utf8')) as Record<string, unknown>;
    payload.sub = 'uid-attacker';
    const forged = `${parts[0]}.${b64url(JSON.stringify(payload))}.${parts[2]}`;
    const result = await verifyFirebaseToken(forged, PROJECT_ID, jwksResponse);
    expect(result.valid).toBe(false);
  });

  it('rejects a token with wrong iss', async () => {
    const token = forgeToken({ ...validClaims(), iss: 'https://securetoken.google.com/other' });
    const result = await verifyFirebaseToken(token, PROJECT_ID, jwksResponse);
    expect(result.valid).toBe(false);
  });

  it('rejects gracefully when JWKS fetch fails', async () => {
    const token = forgeToken(validClaims());
    const result = await verifyFirebaseToken(token, PROJECT_ID, () =>
      Promise.resolve(new Response('boom', { status: 500 })),
    true); // noCache — bypass warm cache from earlier tests
    expect(result.valid).toBe(false);
  });

  it('rejects a garbage token without throwing', async () => {
    const result = await verifyFirebaseToken('not-a-jwt', PROJECT_ID, jwksResponse);
    expect(result.valid).toBe(false);
  });
});
