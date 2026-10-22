import { describe, expect, it, vi } from 'vitest';
import { NotifyUseCase } from '../use-cases/notify-use-case';
import type { BroadcastService } from '../../domain/services/broadcast-service';
import type { BroadcastRepository } from '../../domain/repositories/broadcast-repository';
import type { NotifyUseCaseDto } from '../dtos/notify-use-case-dto';

/** Simple deterministic xorshift32 PRNG. */
function makeRng(seed: number) {
  let state = seed >>> 0;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return (state >>> 0) / 0xffffffff;
  };
}

const seeds = [3101, 3202, 3303];
const operations = 200;
const events = ['sale', 'session', 'sync', '', '  ', 'bad_event', 'A'.repeat(60)];
const tenants = ['tenant-1', '', '   ', 'a'.repeat(129), 'Bad Tenant!', 'valid_tenant-2'];
const pick = (arr: readonly string[], rng: () => number): string =>
  arr[Math.floor(rng() * arr.length)]!;

describe('NotifyUseCase — deterministic fuzz', () => {
  it.each(seeds)('seed %i classifies %i notify requests without crashing', async (seed) => {
    const rng = makeRng(seed);
    const shouldBroadcast = Math.floor(rng() * 2) === 0;
    const insertSucceeds = Math.floor(rng() * 2) === 0;

    const broadcastService = {
      buildPayload: vi.fn(
        (_type: string, _tenantId: string, _data: Record<string, unknown>, createdAt: number) => ({
          type: 'sale',
          tenantId: 'tenant-1',
          data: {},
          createdAt,
        }),
      ),
      shouldBroadcast: vi.fn().mockReturnValue(shouldBroadcast),
    } as unknown as BroadcastService;
    const broadcastRepo = {
      insert: vi.fn().mockResolvedValue(insertSucceeds),
    } as unknown as BroadcastRepository;

    const useCase = new NotifyUseCase(broadcastService, broadcastRepo);

    for (let operation = 0; operation < operations; operation += 1) {
      const dto: NotifyUseCaseDto = {
        tenantId: pick(tenants, rng),
        event: pick(events, rng),
        data: Math.floor(rng() * 2) === 0 ? { count: 1 } : {},
      };

      const result = await useCase.execute(dto);
      expect(typeof result.ok).toBe('boolean');
      if (result.ok) {
        expect(typeof result.data.broadcastId).toBe('string');
      } else {
        expect(typeof result.error).toBe('string');
        expect(result.error.length).toBeGreaterThan(0);
      }
    }
  });
});
