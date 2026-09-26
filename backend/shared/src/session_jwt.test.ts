/**
 * session_jwt tests — HS256 mint/verify contract shared by daftari-api
 * (mints + verifies) and daftari-realtime (/ws upgrade verification).
 * Claims use SECONDS (JWT convention): exp * 1000 <= Date.now() expires.
 */
import { describe, expect, it } from 'vitest';
import { mintSessionJwt, verifySessionJwt } from './session_jwt';

interface SessionClaimsT {
  tid: string;
  usr: string;
  role: string;
  iat: number;
  exp: number;
}

const SECRET = 's3cret';

function claims(overrides: Partial<SessionClaimsT> = {}): SessionClaimsT {
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
});
