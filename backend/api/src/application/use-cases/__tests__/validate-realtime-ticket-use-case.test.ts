/**
 * ValidateRealtimeTicketUseCase Tests
 *
 * Covers the pinned fail-closed contract: ok requires no error AND valid AND
 * a non-empty tenantId; the error field takes precedence over valid and the
 * vocabulary mapping (expired/used/already_used/everything else) is
 * case-insensitive.
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

  it('rejects an empty-string tenantId (fail-closed)', async () => {
    // ok requires a non-empty tenantId; an empty string is not a valid tenant.
    build({ valid: true, tenantId: '' });

    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(result).toEqual({ ok: false, error: 'INVALID_TICKET' });
  });

  it('lets the error field take precedence over valid', async () => {
    build({ valid: true, tenantId: 'tenant-1', error: 'expired' });

    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(result).toEqual({ ok: false, error: 'EXPIRED_TICKET' });
  });

  it('maps an expired ticket to EXPIRED_TICKET', async () => {
    build({ valid: false, error: 'expired' });

    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(result).toEqual({ ok: false, error: 'EXPIRED_TICKET' });
  });

  it('maps an uppercase EXPIRED to EXPIRED_TICKET (case-insensitive)', async () => {
    build({ valid: false, error: 'EXPIRED' });

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

  it('maps an empty-string error to INVALID_TICKET', async () => {
    build({ valid: false, error: '' });

    const result = await useCase.execute({ ticket: 'ticket-abc' });

    expect(result).toEqual({ ok: false, error: 'INVALID_TICKET' });
  });

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    ticketRepo.validateAndConsume.mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute({ ticket: 'ticket-abc' })).rejects.toThrow('db down');
  });
});
