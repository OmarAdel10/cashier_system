import type { RealtimeTicketRepository } from '../../../../shared/src/domain/repositories/realtime-ticket-repository';
import type {
  NewRealtimeTicket,
  TicketValidationResult,
} from '../../../../shared/src/domain/entities/realtime-ticket';

/**
 * In-memory realtime ticket repository.
 *
 * Temporary implementation for Phase 3 (route refactoring). Replaced by the
 * shared TursoRealtimeTicketRepository in Phase 4.
 */
export class InMemoryRealtimeTicketRepository implements RealtimeTicketRepository {
  private readonly tickets = new Map<string, {
    tenantId: string;
    expiresAt: number;
    usedAt: number | null;
  }>();

  async insert(ticket: NewRealtimeTicket): Promise<boolean> {
    if (this.tickets.has(ticket.ticket)) return false;
    this.tickets.set(ticket.ticket, {
      tenantId: ticket.tenantId,
      expiresAt: ticket.expiresAt,
      usedAt: null,
    });
    return true;
  }

  async validateAndConsume(ticket: string, now: number): Promise<TicketValidationResult> {
    const row = this.tickets.get(ticket);
    if (!row) {
      return { valid: false, error: 'INVALID_TICKET' };
    }
    if (row.expiresAt <= now) {
      return { valid: false, error: 'EXPIRED_TICKET' };
    }
    if (row.usedAt !== null) {
      return { valid: false, error: 'ALREADY_USED_TICKET' };
    }
    row.usedAt = now;
    return { valid: true, tenantId: row.tenantId };
  }

  async sweepExpired(now: number): Promise<void> {
    for (const [ticket, row] of this.tickets) {
      if (row.expiresAt <= now) {
        this.tickets.delete(ticket);
      }
    }
  }
}
