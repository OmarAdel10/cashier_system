/**
 * Domain service for ticket validation business rules.
 *
 * Encapsulates pure policy for deciding whether a presented WebSocket ticket
 * is acceptable: it must be present, non-empty, and structurally well-formed.
 * Cryptographic/atomic validation (expiry, single-use, tenant lookup) is
 * delegated to the shared RealtimeTicketRepository at the application layer.
 */
export interface TicketValidationService {
  /**
   * Performs structural validation of a raw ticket string before it is
   * submitted to the ticket repository for atomic validation.
   *
   * @param ticket - Raw ticket string from the ?ticket= query param
   * @returns the normalized ticket value if valid, or an error string
   */
  validateFormat(ticket: string): { ok: true; value: string } | { ok: false; error: string };
}
