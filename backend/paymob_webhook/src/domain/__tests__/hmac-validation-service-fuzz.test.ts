/**
 * Deterministic fuzz tests for HmacValidationServiceImpl.
 *
 * Uses a seeded xorshift32 PRNG so every run is reproducible. Exercises
 * isValid with randomized concatenated strings, signatures, and secrets,
 * verifying it always returns a boolean without crashing.
 */
import { describe, expect, it } from 'vitest';
import { HmacValidationServiceImpl } from '../services/hmac-validation-service.impl';

function makeRng(seed: number) {
  let state = seed >>> 0;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return (state >>> 0) / 0xffffffff;
  };
}

const seeds = [5101, 5202, 5303];
const operations = 200;
const alpha = 'abcdefghijklmnopqrstuvwxyz0123456789';

function randomString(rng: () => number, length: number): string {
  return Array.from({ length }, () => alpha[Math.floor(rng() * alpha.length)]).join('');
}

describe('HmacValidationServiceImpl — deterministic fuzz', () => {
  it.each(seeds)('seed %i validates %i HMACs without crashing', async (seed) => {
    const rng = makeRng(seed);
    const svc = new HmacValidationServiceImpl();

    for (let operation = 0; operation < operations; operation += 1) {
      const concatenated = randomString(rng, Math.floor(rng() * 50) + 1);
      const signature = randomString(rng, 128);
      const secret = randomString(rng, Math.floor(rng() * 30) + 1);

      const result = await svc.isValid(concatenated, signature, secret);
      expect(typeof result).toBe('boolean');
    }
  });
});
