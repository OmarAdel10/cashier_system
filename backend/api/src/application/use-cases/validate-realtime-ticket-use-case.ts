/**
 * Validate Realtime Ticket Use Case
 *
 * Atomically validates and consumes a realtime ticket (GET
 * /auth/ticket/validate). Fails closed: ok is returned only when there is no
 * error AND `valid` is true AND a non-empty tenantId is present — a
 * contradictory payload (e.g. valid + error) is treated as a failure. The
 * error field takes precedence over `valid`, and the repository error
 * vocabulary is matched case-insensitively; this mapping IS the contract the
 * Phase 6 repository implementation must satisfy.
 */
import type { RealtimeTicketRepository } from '../../domain/repositories/realtime-ticket-repository';
import type { TicketValidateDto, TicketValidateResponse } from '../dtos/ticket-validate.dto';

export class ValidateRealtimeTicketUseCase {
  constructor(private readonly ticketRepo: RealtimeTicketRepository) {}

  async execute(dto: TicketValidateDto): Promise<TicketValidateResponse> {
    const now = Date.now();
    const result = await this.ticketRepo.validateAndConsume(dto.ticket, now);
    // Fail closed: ok requires no error AND valid AND a non-empty tenantId.
    // Contradictory data (e.g. valid + error) is treated as a failure.
    if (
      result.error == null &&
      result.valid &&
      result.tenantId != null &&
      result.tenantId.length > 0
    ) {
      return { ok: true, data: { tenantId: result.tenantId } };
    }
    // Vocabulary is case-insensitive; 'used'/'already_used' are both the
    // consumed state; everything else (missing/empty/unknown) is invalid.
    const err = result.error?.toLowerCase();
    if (err === 'expired') {
      return { ok: false, error: 'EXPIRED_TICKET' };
    }
    if (err === 'used' || err === 'already_used') {
      return { ok: false, error: 'ALREADY_USED_TICKET' };
    }
    return { ok: false, error: 'INVALID_TICKET' };
  }
}
