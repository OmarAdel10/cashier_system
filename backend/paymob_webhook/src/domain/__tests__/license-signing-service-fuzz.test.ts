/**
 * Deterministic fuzz tests for LicenseSigningServiceImpl.
 *
 * Uses a seeded xorshift32 PRNG so every run is reproducible. Classifies
 * computePayload and shouldIssue outputs across randomized billing cycles
 * and success/refund/void combinations without crashing.
 */
import { describe, expect, it } from 'vitest';
import { LicenseSigningServiceImpl } from '../services/license-signing-service.impl';
import type { WebhookEvent } from '../entities/webhook-event';

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
const billingCycles: Array<'monthly' | 'yearly' | 'lifetime'> = [
  'monthly',
  'yearly',
  'lifetime',
];

function randomEvent(rng: () => number): WebhookEvent {
  const cycle = billingCycles[Math.floor(rng() * billingCycles.length)] as 'monthly' | 'yearly' | 'lifetime';
  return {
    transactionId: `txn_${Math.floor(rng() * 10_000_000)}`,
    success: Math.floor(rng() * 2) === 0,
    isRefunded: Math.floor(rng() * 2) === 0,
    isVoided: Math.floor(rng() * 2) === 0,
    tenantId: `tenant-${Math.floor(rng() * 1000)}`,
    deviceHwid: `device-${Math.floor(rng() * 1000)}`,
    billingCycle: cycle,
    receivedAt: Math.floor(rng() * 2_000_000_000_000),
  };
}

describe('LicenseSigningServiceImpl — deterministic fuzz', () => {
  it.each(seeds)('seed %i processes %i events without crashing', async (seed) => {
    const rng = makeRng(seed);
    const svc = new LicenseSigningServiceImpl();

    for (let operation = 0; operation < operations; operation += 1) {
      const event = randomEvent(rng);
      const now = Math.floor(rng() * 2_000_000_000_000);

      const payload = svc.computePayload(event, now);
      expect(typeof payload.tenantId).toBe('string');
      expect(payload.tenantId.length).toBeGreaterThan(0);
      expect(typeof payload.deviceHwid).toBe('string');
      expect(payload.deviceHwid.length).toBeGreaterThan(0);
      expect(['monthly', 'yearly', 'lifetime']).toContain(payload.billingCycle);
      expect(typeof payload.createdAt).toBe('number');
      expect(payload.createdAt).toBe(now);

      if (payload.billingCycle === 'lifetime') {
        expect(payload.subscriptionEnd).toBe(0);
        expect(payload.graceEnd).toBe(0);
      } else {
        expect(payload.subscriptionEnd).toBeGreaterThan(now);
        expect(payload.graceEnd).toBeGreaterThan(payload.subscriptionEnd);
      }

      const decision = svc.shouldIssue(event);
      expect(typeof decision.issue).toBe('boolean');
      if (event.success && !event.isRefunded && !event.isVoided) {
        expect(decision.issue).toBe(true);
        expect(decision.reason).toBeUndefined();
      } else {
        expect(decision.issue).toBe(false);
        expect(typeof decision.reason).toBe('string');
        expect(decision.reason!.length).toBeGreaterThan(0);
      }
    }
  });
});
