/**
 * Ticket Validate DTOs
 *
 * Data Transfer Objects for the realtime ticket validate use case.
 */

/**
 * Input data for validating a realtime ticket.
 */
export interface TicketValidateDto {
  readonly ticket: string;
}

/**
 * Output data for validating a realtime ticket.
 */
export interface TicketValidateResponse {
  readonly ok: true;
  readonly data: {
    readonly tenantId: string;
  };
} | {
  readonly ok: false;
  readonly error: 'INVALID_TICKET' | 'EXPIRED_TICKET' | 'ALREADY_USED_TICKET';
};
