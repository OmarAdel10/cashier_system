/**
 * session_jwt tests — HS256 mint/verify contract shared by daftari-api
 * (mints + verifies) and daftari-realtime (/ws upgrade verification).
 * Claims use SECONDS (JWT convention): exp * 1000 <= Date.now() expires.
 */
import { describe, expect, it, vi } from 'vitest';
import { b64urlToJson, bytesToB64url } from './base64';
import { mintSessionJwt, verifySessionJwt, type SessionClaims } from './session_jwt';

const SECRET = 's3cret';

function claims(overrides: Partial<SessionClaims> = {}): SessionClaims {
  const now = Math.floor(Date.now() / 1000);
  return {
    tid: 'tenant-1',
    usr: 'admin',
    role: 'admin',
    jti: 'sess-1',
    iat: now,
    exp: now + 3600,
    ...overrides,
  };
}

/** Re-signs an arbitrary payload with SECRET so iss/aud tests exercise the
 * claim checks rather than the HMAC check. */
async function resign(payload: Record<string, unknown>): Promise<string> {
  const enc = new TextEncoder();
  const header = bytesToB64url(enc.encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const body = bytesToB64url(enc.encode(JSON.stringify(payload)));
  const data = `${header}.${body}`;
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(SECRET),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = bytesToB64url(new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(data))));
  return `${data}.${sig}`;
}

describe('session_jwt', () => {
  it('mints a 3-part token that verifies to identical claims', async () => {
    const c = claims();
    const token = await mintSessionJwt(c, SECRET);
    expect(token.split('.')).toHaveLength(3);
    await expect(verifySessionJwt(token, SECRET)).resolves.toEqual(c);
  });

  it('mintSessionJwt mints jti/iss/aud', async () => {
    const token = await mintSessionJwt(claims({ jti: 'sess-mint' }), SECRET);
    const payload = b64urlToJson(token.split('.')[1]!);
    expect(payload.jti).toBe('sess-mint');
    expect(payload.iss).toBe('daftari-api');
    expect(payload.aud).toBe('daftari-admin');
  });

  it('verifySessionJwt rejects a wrong audience', async () => {
    const token = await mintSessionJwt(claims({ jti: 'sess-aud' }), SECRET);
    const payload = b64urlToJson(token.split('.')[1]!);
    payload.aud = 'daftari-other';
    await expect(verifySessionJwt(await resign(payload), SECRET)).resolves.toBeNull();
  });

  it('verifySessionJwt rejects a wrong issuer', async () => {
    const token = await mintSessionJwt(claims({ jti: 'sess-iss' }), SECRET);
    const payload = b64urlToJson(token.split('.')[1]!);
    payload.iss = 'some-other-api';
    await expect(verifySessionJwt(await resign(payload), SECRET)).resolves.toBeNull();
  });

  it('verifySessionJwt returns the jti', async () => {
    const token = await mintSessionJwt(claims({ jti: 'sess-returns' }), SECRET);
    const verified = await verifySessionJwt(token, SECRET);
    expect(verified?.jti).toBe('sess-returns');
  });

  it('verifySessionJwt rejects a token with an empty or missing jti', async () => {
    const empty = await mintSessionJwt(claims({ jti: '' }), SECRET);
    await expect(verifySessionJwt(empty, SECRET)).resolves.toBeNull();
    const payload = b64urlToJson(empty.split('.')[1]!);
    delete payload.jti;
    await expect(verifySessionJwt(await resign(payload), SECRET)).resolves.toBeNull();
  });

  it('rejects a wrong secret', async () => {
    const token = await mintSessionJwt(claims({ jti: 'sess-2' }), SECRET);
    await expect(verifySessionJwt(token, 'wrong-secret')).resolves.toBeNull();
  });

  it('rejects tampered payloads', async () => {
    const token = await mintSessionJwt(claims({ jti: 'sess-3' }), SECRET);
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
    const expired = await mintSessionJwt(
      claims({ jti: 'sess-4', exp: Math.floor(Date.now() / 1000) - 1 }),
      SECRET,
    );
    await expect(verifySessionJwt(expired, SECRET)).resolves.toBeNull();
  });

  it('rejects claims missing required fields', async () => {
    const empty = await mintSessionJwt(
      { tid: '', usr: '', role: '', jti: '', iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600 },
      SECRET,
    );
    await expect(verifySessionJwt(empty, SECRET)).resolves.toBeNull();
  });

  it('rejects when each required field is individually empty', async () => {
    const emptyFields: Array<Partial<SessionClaims>> = [{ tid: '' }, { usr: '' }, { role: '' }, { jti: '' }];
    for (const override of emptyFields) {
      const token = await mintSessionJwt(claims(override), SECRET);
      await expect(verifySessionJwt(token, SECRET)).resolves.toBeNull();
    }
  });

  it('returns null (not a throw) for an empty secret', async () => {
    const token = await mintSessionJwt(claims({ jti: 'sess-5' }), SECRET);
    // importKey rejects zero-length HMAC keys -> hmac throws -> catch.
    await expect(verifySessionJwt(token, '')).resolves.toBeNull();
  });

  it('rejects alg:none and alg:RS256 headers with garbage signatures', async () => {
    const valid = await mintSessionJwt(claims({ jti: 'sess-6' }), SECRET);
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
    const token = await mintSessionJwt(
      claims({ jti: 'sess-7', exp: Math.floor(Date.now() / 1000) }),
      SECRET,
    );
    await expect(verifySessionJwt(token, SECRET)).resolves.toBeNull();
  });

  it('rejects a signed payload whose exp is a string', async () => {
    const now = Math.floor(Date.now() / 1000);
    const stringy = await mintSessionJwt(
      { tid: 't', usr: 'u', role: 'admin', jti: 'sess-stringy', iat: now, exp: `${now + 3600}` } as unknown as SessionClaims,
      SECRET,
    );
    await expect(verifySessionJwt(stringy, SECRET)).resolves.toBeNull();
  });

  it('rejects exp whose ms conversion overflows to Infinity', async () => {
    // 1e306 is finite and JSON-representable; 1e306 * 1000 overflows to
    // Infinity — without the multiplied isFinite check this token would
    // never expire (coverage round 2, G3).
    const now = Math.floor(Date.now() / 1000);
    const huge = await mintSessionJwt(
      { tid: 't', usr: 'u', role: 'admin', jti: 'sess-huge', iat: now, exp: 1e306 },
      SECRET,
    );
    await expect(verifySessionJwt(huge, SECRET)).resolves.toBeNull();
  });

  it('rejects non-string tid/usr/role (each individually)', async () => {
    const now = Math.floor(Date.now() / 1000);
    for (const field of ['tid', 'usr', 'role']) {
      const c: Record<string, unknown> = {
        tid: 't',
        usr: 'u',
        role: 'admin',
        jti: 'sess-nonstring',
        iat: now,
        exp: now + 3600,
      };
      c[field] = 123;
      const token = await mintSessionJwt(c as unknown as SessionClaims, SECRET);
      await expect(verifySessionJwt(token, SECRET)).resolves.toBeNull();
    }
  });

  it('rejects exp*1000 === now exactly (pins <= vs <)', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(1_800_000_000_000));
    try {
      const token = await mintSessionJwt(
        { tid: 't', usr: 'u', role: 'admin', jti: 'sess-fake-timer', iat: 1_799_999_990, exp: 1_800_000_000 },
        SECRET,
      );
      await expect(verifySessionJwt(token, SECRET)).resolves.toBeNull();
    } finally {
      vi.useRealTimers();
    }
  });
});
