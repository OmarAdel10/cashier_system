/**
 * password_kdf tests — byte-compatibility with the Dart reference
 * implementation, pinned by the frozen fixtures generated on the Dart
 * side (tool/gen_kdf_fixtures.dart). Dart is the oracle-holder; this
 * suite must reproduce every vector byte-for-byte.
 */
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { hashTagged, parseStored, verifyTagged } from './password_kdf';

interface KdfVector {
  password: string;
  iterations: number;
  salt_b64url: string;
  expected: string;
}

const vectors = JSON.parse(
  readFileSync(new URL('../fixtures/kdf_vectors.json', import.meta.url), 'utf8'),
) as KdfVector[];

// Frozen at the Dart cap boundary (T02 QA round 2): the cap is a strict
// greater-than, so exactly one million must still verify.
const FROZEN_1M =
  'pbkdf2-sha512$1000000$c2FsdHNhbHQ$tgutnHDhzzaLJy0Xrnm99xBJsSwvGjo5/8WUXUFvgNg=';

describe('password_kdf — Dart-generated fixture vectors', () => {
  it('has the expected five vectors', () => {
    expect(vectors).toHaveLength(5);
  });

  it('matches every vector byte-for-byte and verifies it', async () => {
    for (const v of vectors) {
      await expect(hashTagged(v.password, v.iterations, v.salt_b64url)).resolves.toBe(v.expected);
      await expect(verifyTagged(v.expected, v.password)).resolves.toBe(true);
    }
  });

  it('accepts the padded-salt vector (Dart salts are padded)', async () => {
    const padded = vectors.find((v) => v.salt_b64url.endsWith('='));
    expect(padded).toBeDefined();
    await expect(verifyTagged(padded!.expected, padded!.password)).resolves.toBe(true);
  });
});

describe('password_kdf — rejection paths', () => {
  it('rejects a wrong password', async () => {
    await expect(verifyTagged(vectors[0]!.expected, 'wrong')).resolves.toBe(false);
  });

  it('rejects garbage and non-tagged values', async () => {
    await expect(verifyTagged('garbage', 'x')).resolves.toBe(false);
    await expect(verifyTagged('plainLegacyHash', 'x')).resolves.toBe(false);
    expect(parseStored('garbage')).toBeNull();
    expect(parseStored('argon2id$16$1$1$salt$hash')).toBeNull();
  });

  it('rejects four-part values with a different scheme', async () => {
    expect(parseStored('pbkdf2-sha256$1000$c2FsdHNhbHQ$hash')).toBeNull();
    expect(parseStored('scrypt$16384$salt$hash')).toBeNull();
  });

  it('rejects invalid iteration counts (non-numeric, zero, negative, oversized)', async () => {
    expect(parseStored('pbkdf2-sha512$abc$c2FsdHNhbHQ$hash')).toBeNull();
    expect(parseStored('pbkdf2-sha512$0$c2FsdHNhbHQ$hash')).toBeNull();
    expect(parseStored('pbkdf2-sha512$-1$c2FsdHNhbHQ$hash')).toBeNull();
    expect(parseStored('pbkdf2-sha512$1000001$c2FsdHNhbHQ$hash')).toBeNull();
  });

  it('rejects hash segments with the wrong length before deriving', async () => {
    expect(parseStored('pbkdf2-sha512$1000$c2FsdHNhbHQ$')).not.toBeNull();
    await expect(verifyTagged('pbkdf2-sha512$1000$c2FsdHNhbHQ$', 'abc123')).resolves.toBe(false);
    const short = vectors[0]!.expected.slice(0, -1);
    await expect(verifyTagged(short, vectors[0]!.password)).resolves.toBe(false);
  });

  it('accepts the frozen vector at exactly the 1,000,000-iteration cap', async () => {
    await expect(verifyTagged(FROZEN_1M, 'abc123')).resolves.toBe(true);
  });

  it('rejects non-decimal iteration encodings (Dart int.tryParse parity)', () => {
    expect(parseStored('pbkdf2-sha512$1e6$c2FsdHNhbHQ$hash')).toBeNull();
    expect(parseStored('pbkdf2-sha512$0x10$c2FsdHNhbHQ$hash')).toBeNull();
    expect(parseStored('pbkdf2-sha512$ 1000 $c2FsdHNhbHQ$hash')).toBeNull();
  });

  it('rejects a non-decodable salt via the catch branch', async () => {
    // parseStored accepts and the 44-char pre-check passes; b64ToBytes
    // throws on '!' — only the verifyTagged catch stands between this
    // and an unhandled rejection.
    const hash44 = vectors[0]!.expected.split('$')![3]!;
    await expect(
      verifyTagged(`pbkdf2-sha512$1000$!!not-base64!!$${hash44}`, 'x'),
    ).resolves.toBe(false);
  });
});

describe('password_kdf — round-trips', () => {
  it('generates an unpadded 43-char salt when omitted', async () => {
    const stored = await hashTagged('abc123');
    const parts = stored.split('$');
    expect(parts[0]).toBe('pbkdf2-sha512');
    expect(parts[1]).toBe('10000');
    expect(parts[2]).toHaveLength(43);
    expect(parts[3]).toHaveLength(44);
    await expect(verifyTagged(stored, 'abc123')).resolves.toBe(true);
    await expect(verifyTagged(stored, 'nope')).resolves.toBe(false);
  });

  it('round-trips an empty password', async () => {
    const stored = await hashTagged('', 1000, 'c2FsdHNhbHQ');
    await expect(verifyTagged(stored, '')).resolves.toBe(true);
    await expect(verifyTagged(stored, 'x')).resolves.toBe(false);
  });

  it('tolerates an empty salt segment', async () => {
    const stored = await hashTagged('abc123', 1000, '');
    await expect(verifyTagged(stored, 'abc123')).resolves.toBe(true);
  });
});
