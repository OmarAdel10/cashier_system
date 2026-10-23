/**
 * Deterministic fuzz tests for ProcessWebhookUseCase.
 *
 * Uses a seeded xorshift32 PRNG so every run is reproducible. Exercises
 * the HMAC validation, idempotency check, license computation, and
 * decision paths across randomized inputs without crashing.
 */
import { describe, expect, it, vi } from 'vitest';
import { ProcessWebhookUseCase } from '../use-cases/process-webhook-use-case';
import type { HmacValidationService } from '../../domain/services/hmac-validation-service';
import type { WebhookEventRepository } from '../../domain/repositories/webhook-event-repository';
import type { LicenseSigningService } from '../../domain/services/license-signing-service';
import type { ProcessWebhookDto } from '../dtos/process-webhook-dto';
import type { WebhookEvent } from '../../domain/entities/webhook-event';

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

function randomEvent(rng: () => number): WebhookEvent {
  const cycle = billingCycles[Math.floor(rng() * billingCycles.length)] as
    | 'monthly'
    | 'yearly'
    | 'lifetime';
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

describe('ProcessWebhookUseCase — deterministic fuzz', () => {
  it.each(seeds)(
    'seed %i processes %i webhook events without crashing',
    async (seed) => {
      const rng = makeRng(seed);
      const hmacValid = Math.floor(rng() * 2) === 0;
      const insertSucceeds = Math.floor(rng() * 2) === 0;

      const hmacValidationService = {
        isValid: vi.fn().mockResolvedValue(hmacValid),
      } as unknown as HmacValidationService;
      const webhookEventRepo = {
        insert: vi.fn().mockResolvedValue(insertSucceeds),
      } as unknown as WebhookEventRepository;
      const licenseSigningService = {
        computePayload: vi.fn().mockReturnValue({
          tenantId: 'tenant-1',
          deviceHwid: 'device-abc',
          subscriptionEnd: 1_769_000_000_000,
          billingCycle: 'monthly' as const,
          graceEnd: 1_769_604_000_000,
          createdAt: 1_769_000_000_000,
        }),
        shouldIssue: vi.fn().mockReturnValue({ issue: true }),
      } as unknown as LicenseSigningService;

      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );

      for (let operation = 0; operation < operations; operation += 1) {
        const event = randomEvent(rng);
        const dto: ProcessWebhookDto = {
          event,
          concatenated: 'concat-string-123',
          signatureHex: 'abc123def456',
          hmacSecret: 'secret-123',
        };

        const result = await useCase.execute(dto);
        expect(typeof result.ok).toBe('boolean');
        if (result.ok) {
          expect(typeof result.data.payload.tenantId).toBe('string');
          expect(typeof result.data.decision.issue).toBe('boolean');
        } else {
          expect(typeof result.error).toBe('string');
          expect(result.error.length).toBeGreaterThan(0);
        }
      }
    }
  );
});
