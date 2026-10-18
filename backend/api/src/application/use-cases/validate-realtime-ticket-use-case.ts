/**
 * Validate Realtime Ticket Use Case
 *
 * Atomically validates and consumes a realtime ticket (GET
 * /auth/ticket/validate). The repository's error vocabulary is mapped to the
 * DTO's pins here: this mapping IS the contract the Phase 6 repository
 * implementation must satisfy.
 */
import type { RealtimeTicketRepository } from '../../domain/repositories/realtime-ticket-repository';
import type { TicketValidateDto, TicketValidateResponse } from '../dtos/ticket-validate.dto';

export class ValidateRealtimeTicketUseCase {
  constructor(private readonly ticketRepo: RealtimeTicketRepository) {}

  async execute(dto: TicketValidateDto): Promise<TicketValidateResponse> {
    const now = Date.now();
    const result = await this.ticketRepo.validateAndConsume(dto.ticket, now);
    if (result.valid && result.tenantId != null) {
      return { ok: true, data: { tenantId: result.tenantId } };
    }
    // 'used'/'already_used' are both the consumed state; everything else
    // (not_found, missing error, unknown vocabulary) is invalid.
    if (result.error === 'expired') {
      return { ok: false, error: 'EXPIRED_TICKET' };
    }
    if (result.error === 'used' || result.error === 'already_used') {
      return { ok: false, error: 'ALREADY_USED_TICKET' };
    }
    return { ok: false, error: 'INVALID_TICKET' };
  }
}
