/**
 * Deterministic fuzz tests for IssueLicenseUseCase.
 *
 * Uses a seeded xorshift32 PRNG so every run is reproducible. Exercises
 * the signing success and failure paths across randomized payloads without
 * crashing.
 */
import { describe, expect, it, vi } from 'vitest';
import { IssueLicenseUseCase } from '../use-cases/issue-license-use-case';
import type { LicensePayload } from '../../domain/value-objects/license-payload';
import type { IssueLicenseDto } from '../dtos/issue-license-dto';

function makeRng(seed: number) {
  let state = seed >>> 0;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return (state >>> 0) / 0xffffffff;
  };
}

const seeds = [6101, 6202, 6303];
const operations = 200;
const billingCycles: Array<'monthly' | 'yearly' | 'lifetime'> = [
  'monthly',
  'yearly',
  'lifetime',
];

function randomPayload(rng: () => number): LicensePayload {
  const cycle = billingCycles[Math.floor(rng() * billingCycles.length)] as
    | 'monthly'
    | 'yearly'
    | 'lifetime';
  return {
    tenantId: `tenant-${Math.floor(rng() * 1000)}`,
    deviceHwid: `device-${Math.floor(rng() * 1000)}`,
    subscriptionEnd:
      cycle === 'lifetime'
        ? 0
        : Math.floor(rng() * 2_000_000_000_000) + 1_000_000_000_000,
    billingCycle: cycle,
    graceEnd: cycle === 'lifetime' ? 0 : Math.floor(rng() * 2_000_000_000_000),
    createdAt: Math.floor(rng() * 2_000_000_000_000),
  };
}

describe('IssueLicenseUseCase — deterministic fuzz', () => {
  it.each(seeds)(
    'seed %i processes %i license issuance requests without crashing',
    async (seed) => {
      const rng = makeRng(seed);
      const signingSucceeds = Math.floor(rng() * 2) === 0;

      const signLicenseKey = vi.fn().mockResolvedValue('signed-license-key');
      if (!signingSucceeds) {
        signLicenseKey.mockRejectedValue(new Error('signing failed'));
      }

      const useCase = new IssueLicenseUseCase(signLicenseKey);

      for (let operation = 0; operation < operations; operation += 1) {
        const payload = randomPayload(rng);
        const dto: IssueLicenseDto = { payload, privateKeyB64: 'key-base64' };

        const result = await useCase.execute(dto);
        expect(typeof result.ok).toBe('boolean');
        if (result.ok) {
          expect(typeof result.data.licenseKey).toBe('string');
          expect(result.data.licenseKey.length).toBeGreaterThan(0);
        } else {
          expect(typeof result.error).toBe('string');
          expect(result.error.length).toBeGreaterThan(0);
        }
      }
    }
  );
});
