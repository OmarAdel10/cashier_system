import type { TicketValidationService } from './ticket-validation-service';

/**
 * Default implementation of TicketValidationService.
 *
 * Pure structural checks. The ticket repository (shared, Turso-backed) owns
 * atomic expiry / single-use / tenant validation.
 */
export class TicketValidationServiceImpl implements TicketValidationService {
  validateFormat(
    ticket: string,
  ): { ok: true; value: string } | { ok: false; error: string } {
    const value = (ticket ?? '').trim();
    if (value.length === 0) {
      return { ok: false, error: 'MISSING_TICKET' };
    }
    // Reject control characters and whitespace inside the ticket value.
    if (/[\s\u0000-\u001f\u007f]/.test(value)) {
      return { ok: false, error: 'INVALID_TICKET' };
    }
    return { ok: true, value };
  }
}
