/**
 * session_jwt tests — HS256 mint/verify contract shared by daftari-api
 * (mints + verifies) and daftari-realtime (/ws upgrade verification).
 * Claims use SECONDS (JWT convention): exp * 1000 <= Date.now() expires.
 */
import { describe, expect, it } from 'vitest';
import { bytesToB64url } from './base64';
import { mintSessionJwt, verifySessionJwt, type SessionClaims } from './session_jwt';

const SECRET = 's3cret';

function claims(overrides: Partial<SessionClaims> = {}): SessionClaims {
  const now = Math.floor(Date.now() / 1000);
  return {
    tid: 'tenant-1',
    usr: 'admin',
    role: 'admin',
    iat: now,
    exp: now + 3600,
    ...overrides,
  };
}

describe('session_jwt', () => {
  it('mints a 3-part token that verifies to identical claims', async () => {
    const c = claims();
    const token = await mintSessionJwt(c, SECRET);
    expect(token.split('.')).toHaveLength(3);
    await expect(verifySessionJwt(token, SECRET)).resolves.toEqual(c);
  });

  it('rejects a wrong secret', async () => {
    const token = await mintSessionJwt(claims(), SECRET);
    await expect(verifySessionJwt(token, 'wrong-secret')).resolves.toBeNull();
  });

  it('rejects tampered payloads', async () => {
    const token = await mintSessionJwt(claims(), SECRET);
    const parts = token.split('.');
    const tampered = `${parts[0]}.${parts[1]!.slice(0, -2)}xx.${parts[2]}`;
    await expect(verifySessionJwt(tampered, SECRET)).resolves.toBeNull();
  });

  it('rejects malformed input', async () => {
    await expect(verifySessionJwt('garbage', SECRET)).resolves.toBeNull();
    await expect(verifySessionJwt('', SECRET)).resolves.toBeNull();
    await expect(verifySessionJwt('a.b.c', SECRET)).resolves.toBeNull();
  });

  it('rejects expired tokens', async () => {
    const expired = await mintSessionJwt(claims({ exp: Math.floor(Date.now() / 1000) - 1 }), SECRET);
    await expect(verifySessionJwt(expired, SECRET)).resolves.toBeNull();
  });

  it('rejects claims missing required fields', async () => {
    const empty = await mintSessionJwt(
      { tid: '', usr: '', role: '', iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600 },
      SECRET,
    );
    await expect(verifySessionJwt(empty, SECRET)).resolves.toBeNull();
  });

  it('rejects when each required field is individually empty', async () => {
    const emptyFields: Array<Partial<SessionClaims>> = [{ tid: '' }, { usr: '' }, { role: '' }];
    for (const override of emptyFields) {
      const token = await mintSessionJwt(claims(override), SECRET);
      await expect(verifySessionJwt(token, SECRET)).resolves.toBeNull();
    }
  });

  it('returns null (not a throw) for an empty secret', async () => {
    const token = await mintSessionJwt(claims(), SECRET);
    // importKey rejects zero-length HMAC keys -> hmac throws -> catch.
    await expect(verifySessionJwt(token, '')).resolves.toBeNull();
  });

  it('rejects alg:none and alg:RS256 headers with garbage signatures', async () => {
    const valid = await mintSessionJwt(claims(), SECRET);
    const payload = valid.split('.')[1]!;
    const noneHeader = bytesToB64url(
      new TextEncoder().encode(JSON.stringify({ alg: 'none', typ: 'JWT' })),
    );
    await expect(verifySessionJwt(`${noneHeader}.${payload}.garbage`, SECRET)).resolves.toBeNull();
    const rsHeader = bytesToB64url(
      new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })),
    );
    await expect(verifySessionJwt(`${rsHeader}.${payload}.garbage`, SECRET)).resolves.toBeNull();
  });

  it('rejects a token whose exp equals now (strictly expired)', async () => {
    const token = await mintSessionJwt(claims({ exp: Math.floor(Date.now() / 1000) }), SECRET);
    await expect(verifySessionJwt(token, SECRET)).resolves.toBeNull();
  });

  it('rejects a signed payload whose exp is a string', async () => {
    const now = Math.floor(Date.now() / 1000);
    const stringy = await mintSessionJwt(
      { tid: 't', usr: 'u', role: 'admin', iat: now, exp: `${now + 3600}` } as unknown as SessionClaims,
      SECRET,
    );
    await expect(verifySessionJwt(stringy, SECRET)).resolves.toBeNull();
  });
});
