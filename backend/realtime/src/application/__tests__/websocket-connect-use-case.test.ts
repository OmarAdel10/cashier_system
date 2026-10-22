import { describe, expect, it, vi } from 'vitest';
import { WebSocketConnectUseCase } from '../use-cases/websocket-connect-use-case';
import type { TicketValidationService } from '../../domain/services/ticket-validation-service';
import type { RealtimeTicketRepository } from '../../../../shared/src/domain/repositories/realtime-ticket-repository';
import type { WebSocketConnectDto } from '../dtos/websocket-connect-dto';

function makeDto(overrides: Partial<WebSocketConnectDto> = {}): WebSocketConnectDto {
  return { ticket: 'valid-ticket-123', ...overrides };
}

function makeUseCase(overrides: {
  ticketValidationService?: Partial<TicketValidationService>;
  ticketRepo?: Partial<RealtimeTicketRepository>;
} = {}) {
  const ticketValidationService = {
    validateFormat: vi.fn((ticket: string) =>
      ticket ? { ok: true, value: ticket } : { ok: false, error: 'MISSING_TICKET' },
    ),
    ...overrides.ticketValidationService,
  };
  const ticketRepo = {
    validateAndConsume: vi.fn().mockResolvedValue({ valid: true, tenantId: 'tenant-1' }),
    ...overrides.ticketRepo,
  };
  return { useCase: new WebSocketConnectUseCase(
    ticketValidationService as unknown as TicketValidationService,
    ticketRepo as unknown as RealtimeTicketRepository,
  ), ticketValidationService, ticketRepo };
}

describe('WebSocketConnectUseCase — ticket validation for WebSocket auth', () => {
  it('valid ticket → ok with tenantId', async () => {
    const { useCase, ticketRepo } = makeUseCase();
    const result = await useCase.execute(makeDto());
    expect(result).toMatchObject({ ok: true, data: { tenantId: 'tenant-1' } });
    expect(ticketRepo.validateAndConsume).toHaveBeenCalledWith('valid-ticket-123', expect.any(Number));
  });

  it('missing ticket → MISSING_TICKET, no repo work', async () => {
    const { useCase, ticketRepo } = makeUseCase({
      ticketValidationService: { validateFormat: vi.fn(() => ({ ok: false, error: 'MISSING_TICKET' } as const)) },
    });
    const result = await useCase.execute(makeDto({ ticket: '' }));
    expect(result).toMatchObject({ ok: false, error: 'MISSING_TICKET' });
    expect(ticketRepo.validateAndConsume).not.toHaveBeenCalled();
  });

  it('invalid format → INVALID_TICKET, no repo work', async () => {
    const { useCase, ticketRepo } = makeUseCase({
      ticketValidationService: { validateFormat: vi.fn(() => ({ ok: false, error: 'INVALID_TICKET' } as const)) },
    });
    const result = await useCase.execute(makeDto({ ticket: 'a b' }));
    expect(result).toMatchObject({ ok: false, error: 'INVALID_TICKET' });
    expect(ticketRepo.validateAndConsume).not.toHaveBeenCalled();
  });

  it('expired ticket → EXPIRED_TICKET', async () => {
    const { useCase, ticketRepo } = makeUseCase({
      ticketRepo: { validateAndConsume: vi.fn().mockResolvedValue({ valid: false, error: 'EXPIRED_TICKET' }) },
    });
    const result = await useCase.execute(makeDto());
    expect(result).toMatchObject({ ok: false, error: 'EXPIRED_TICKET' });
  });

  it('already used ticket → ALREADY_USED_TICKET', async () => {
    const { useCase, ticketRepo } = makeUseCase({
      ticketRepo: { validateAndConsume: vi.fn().mockResolvedValue({ valid: false, error: 'ALREADY_USED_TICKET' }) },
    });
    const result = await useCase.execute(makeDto());
    expect(result).toMatchObject({ ok: false, error: 'ALREADY_USED_TICKET' });
  });

  it('invalid ticket → INVALID_TICKET', async () => {
    const { useCase, ticketRepo } = makeUseCase({
      ticketRepo: { validateAndConsume: vi.fn().mockResolvedValue({ valid: false, error: 'INVALID_TICKET' }) },
    });
    const result = await useCase.execute(makeDto());
    expect(result).toMatchObject({ ok: false, error: 'INVALID_TICKET' });
  });

  it('validation fails without tenantId → VALIDATION_FAILED', async () => {
    const { useCase, ticketRepo } = makeUseCase({
      ticketRepo: { validateAndConsume: vi.fn().mockResolvedValue({ valid: true }) },
    });
    const result = await useCase.execute(makeDto());
    expect(result).toMatchObject({ ok: false, error: 'VALIDATION_FAILED' });
  });

  it('unexpected error → VALIDATION_FAILED', async () => {
    const { useCase, ticketRepo } = makeUseCase({
      ticketRepo: { validateAndConsume: vi.fn().mockResolvedValue({ valid: false, error: 'UNKNOWN_ERROR' }) },
    });
    const result = await useCase.execute(makeDto());
    expect(result).toMatchObject({ ok: false, error: 'VALIDATION_FAILED' });
  });
});
