/**
 * Ticket value object.
 *
 * Represents a short-lived, single-use authentication ticket issued by the
 * API for authenticating WebSocket connections to the realtime worker.
 * Tickets are tenant-scoped and time-bound.
 */
export interface Ticket {
  /** Opaque ticket string presented by the client on the ?ticket= query param. */
  readonly value: string;
  /** Tenant this ticket was issued for. */
  readonly tenantId: string;
  /** Unix timestamp (ms) after which the ticket is no longer valid. */
  readonly expiresAt: number;
}

/**
 * Result of validating and consuming a ticket.
 */
export interface TicketValidationResult {
  readonly valid: boolean;
  readonly tenantId?: string;
  readonly error?: string;
}
