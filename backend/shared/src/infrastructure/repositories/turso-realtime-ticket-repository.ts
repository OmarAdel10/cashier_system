import { inject, injectable } from 'tsyringe';
import type { TursoDb } from '../../turso';
import type { NewRealtimeTicket, RealtimeTicket, TicketValidationResult } from '../../domain/entities/realtime-ticket';
import type { RealtimeTicketRepository } from '../../domain/repositories/realtime-ticket-repository';

@injectable()
export class TursoRealtimeTicketRepository implements RealtimeTicketRepository {
  constructor(@inject('TursoDb') private readonly db: TursoDb) {}

  async insert(ticket: NewRealtimeTicket): Promise<boolean> {
    const result = await this.db.exec(
      `INSERT INTO realtime_tickets (ticket, tenant_id, expires_at, used_at) VALUES (?, ?, ?, NULL)`,
      [ticket.ticket, ticket.tenantId, ticket.expiresAt],
    );
    return result.rowsAffected > 0;
  }

  async validateAndConsume(ticket: string, now: number): Promise<TicketValidationResult> {
    const result = await this.db.exec(
      `SELECT ticket, tenant_id, expires_at, used_at FROM realtime_tickets WHERE ticket = ?`,
      [ticket],
    );
    const row = result.rows[0] as { ticket: string; tenant_id: string; expires_at: number; used_at: number | null } | undefined;

    if (!row) {
      return { valid: false, error: 'INVALID_TICKET' };
    }

    if (row.expires_at <= now) {
      return { valid: false, error: 'EXPIRED_TICKET' };
    }

    if (row.used_at !== null) {
      return { valid: false, error: 'ALREADY_USED_TICKET' };
    }

    const updateResult = await this.db.exec(
      `UPDATE realtime_tickets SET used_at = ? WHERE ticket = ? AND used_at IS NULL`,
      [now, ticket],
    );

    if (updateResult.rowsAffected === 0) {
      return { valid: false, error: 'ALREADY_USED_TICKET' };
    }

    return { valid: true, tenantId: row.tenant_id };
  }

  async sweepExpired(now: number): Promise<void> {
    await this.db.exec(
      `DELETE FROM realtime_tickets WHERE expires_at <= ?`,
      [now],
    );
  }
}
