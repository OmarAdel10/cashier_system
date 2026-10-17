/**
 * Ticket Issue DTOs
 *
 * Data Transfer Objects for the realtime ticket issue use case.
 */

/**
 * Input data for issuing a realtime ticket.
 */
export interface TicketIssueDto {
  readonly tenantId: string;
}

/**
 * Output data for issuing a realtime ticket.
 */
export type TicketIssueResponse =
  | {
      readonly ok: true;
      readonly data: {
        readonly ticket: string;
        readonly expiresAt: number;
      };
    }
  | {
      readonly ok: false;
      readonly error: 'TICKET_CREATION_FAILED';
    };
