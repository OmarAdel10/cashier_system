import { describe, expect, it, vi } from 'vitest';
import { WebSocketConnectUseCase } from '../use-cases/websocket-connect-use-case';
import type { TicketValidationService } from '../../domain/services/ticket-validation-service';
import type { RealtimeTicketRepository } from '../../../../shared/src/domain/repositories/realtime-ticket-repository';
import type { WebSocketConnectDto } from '../dtos/websocket-connect-dto';

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
const tickets = ['valid-ticket', '', 'a b', 'ticket\u0000', 'expired-ticket', 'used-ticket', 'unknown-ticket', 'a'.repeat(256), 'ticket-with-dashes_and_underscores'];
const pick = (arr: readonly string[], rng: () => number): string =>
  arr[Math.floor(rng() * arr.length)]!;

describe('WebSocketConnectUseCase — deterministic fuzz', () => {
  it.each(seeds)('seed %i classifies %i connect requests without crashing', async (seed) => {
    const rng = makeRng(seed);
    const valid = Math.floor(rng() * 2) === 0;
    const formatOk = Math.floor(rng() * 2) === 0;

    const ticketValidationService = {
      validateFormat: vi.fn((ticket: string) =>
        formatOk && ticket ? { ok: true, value: ticket } : { ok: false, error: ticket ? 'INVALID_TICKET' : 'MISSING_TICKET' } as const,
      ),
    } as unknown as TicketValidationService;

    const outcomes = [
      { valid: true, tenantId: 'tenant-1' },
      { valid: false, error: 'INVALID_TICKET' },
      { valid: false, error: 'EXPIRED_TICKET' },
      { valid: false, error: 'ALREADY_USED_TICKET' },
    ];
    const outcome = outcomes[Math.floor(rng() * outcomes.length)];

    const ticketRepo = {
      validateAndConsume: vi.fn().mockResolvedValue(valid ? { valid: true, tenantId: 'tenant-1' } : outcome),
    } as unknown as RealtimeTicketRepository;

    const useCase = new WebSocketConnectUseCase(ticketValidationService, ticketRepo);

    for (let operation = 0; operation < operations; operation += 1) {
      const dto: WebSocketConnectDto = {
        ticket: pick(tickets, rng),
      };

      const result = await useCase.execute(dto);
      expect(typeof result.ok).toBe('boolean');
      if (result.ok) {
        expect(typeof result.data.tenantId).toBe('string');
        expect(result.data.tenantId.length).toBeGreaterThan(0);
      } else {
        expect(typeof result.error).toBe('string');
        expect(result.error.length).toBeGreaterThan(0);
      }
    }
  });
});
