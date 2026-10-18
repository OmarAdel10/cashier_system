/**
 * ValidateRealtimeTicketUseCase Tests
 *
 * Covers the pinned repository-error mapping contract: valid + tenantId
 * passes through; expired/used/already_used/not_found/undefined/unknown error
 * vocabulary maps to the DTO error arms.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ValidateRealtimeTicketUseCase } from '../validate-realtime-ticket-use-case';

const FIXED_NOW = 1_700_000_000_000;

const makeTicketRepo = (result: { valid: boolean; tenantId?: string; error?: string }) => ({
  validateAndConsume: vi.fn().mockResolvedValue(result),
});

describe('ValidateRealtimeTicketUseCase', () => {
  let ticketRepo: ReturnType<typeof makeTicketRepo>;
  let useCase: ValidateRealtimeTicketUseCase;

  const build = (result: { valid: boolean; tenantId?: string; error?: string }) => {
    ticketRepo = makeTicketRepo(result);
    useCase = new ValidateRealtimeTicketUseCase(ticketRepo as any);
  };

  beforeEach(() => {
    build({ valid: true, tenantId: 'tenant-1' });
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('returns the tenantId when the ticket is valid', async () => {
    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(ticketRepo.validateAndConsume).toHaveBeenCalledWith('ticket-abc', FIXED_NOW);
    expect(result).toEqual({ ok: true, data: { tenantId: 'tenant-1' } });
  });

  it('maps an expired ticket to EXPIRED_TICKET', async () => {
    build({ valid: false, error: 'expired' });

    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(result).toEqual({ ok: false, error: 'EXPIRED_TICKET' });
  });

  it('maps a used ticket to ALREADY_USED_TICKET', async () => {
    build({ valid: false, error: 'used' });

    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(result).toEqual({ ok: false, error: 'ALREADY_USED_TICKET' });
  });

  it('maps an already_used ticket to ALREADY_USED_TICKET', async () => {
    build({ valid: false, error: 'already_used' });

    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(result).toEqual({ ok: false, error: 'ALREADY_USED_TICKET' });
  });

  it('maps not_found to INVALID_TICKET', async () => {
    build({ valid: false, error: 'not_found' });

    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(result).toEqual({ ok: false, error: 'INVALID_TICKET' });
  });

  it('maps a missing error to INVALID_TICKET', async () => {
    build({ valid: false });

    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(result).toEqual({ ok: false, error: 'INVALID_TICKET' });
  });

  it('maps an unknown error string to INVALID_TICKET', async () => {
    build({ valid: false, error: 'something_else' });

    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(result).toEqual({ ok: false, error: 'INVALID_TICKET' });
  });

  it('maps valid-without-tenantId to INVALID_TICKET', async () => {
    build({ valid: true });

    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(result).toEqual({ ok: false, error: 'INVALID_TICKET' });
  });
});
