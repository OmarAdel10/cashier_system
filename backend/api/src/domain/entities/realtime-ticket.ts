/**
 * Realtime Ticket Entity
 *
 * Represents a short-lived ticket issued by the API for authenticating
 * WebSocket connections to the realtime worker. Tickets are single-use,
 * time-bound, and tenant-scoped.
 */
export interface RealtimeTicket {
  readonly ticket: string;
  readonly tenantId: string;
  readonly expiresAt: number;
  readonly usedAt?: number;
  readonly createdAt: number;
}

/**
 * Input for creating a new RealtimeTicket.
 */
export interface NewRealtimeTicket {
  ticket: string;
  tenantId: string;
  expiresAt: number;
  createdAt: number;
}

/**
 * Ticket validation result.
 */
export interface TicketValidationResult {
  readonly valid: boolean;
  readonly tenantId?: string;
  readonly error?: string;
}
