/**
 * Realtime Ticket Repository Interface
 *
 * Defines the contract for storing and validating realtime authentication tickets.
 * Tickets are short-lived, single-use tokens for WebSocket authentication.
 */
import type { NewRealtimeTicket, RealtimeTicket, TicketValidationResult } from '../../domain/entities/realtime-ticket';

export interface RealtimeTicketRepository {
  /**
   * Insert a new ticket.
   * @returns true if inserted, false if ticket already exists (should not happen with UUID)
   */
  insert(ticket: NewRealtimeTicket): Promise<boolean>;

  /**
   * Validate and consume a ticket (atomic operation).
   * Returns the tenantId if valid and not expired/used, null otherwise.
   */
  validateAndConsume(ticket: string, now: number): Promise<TicketValidationResult>;

  /**
   * Clean up expired tickets (can be called periodically).
   */
  sweepExpired(now: number): Promise<void>;
}
