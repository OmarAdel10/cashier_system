import type { TicketValidationService } from '../../domain/services/ticket-validation-service';
import type { RealtimeTicketRepository } from '../../../../shared/src/domain/repositories/realtime-ticket-repository';
import type { WebSocketConnectDto, WebSocketConnectResponse } from '../dtos/websocket-connect-dto';

/**
 * Use case for authenticating a WebSocket connection via a short-lived ticket.
 *
 * Validates the ticket format (presence, charset, length cap), then atomically
 * validates and consumes it through the shared RealtimeTicketRepository (expiry,
 * single-use, tenant lookup). On success returns the tenantId used to route the
 * WebSocket to the tenant's Durable Object.
 */
export class WebSocketConnectUseCase {
  /** Max ticket length before repository lookup (DoS guard). */
  private static readonly MAX_TICKET_LENGTH = 255;

  /** Ticket charset: base64url-safe alphanumerics, hyphens, underscores only. */
  private static readonly TICKET_RE = /^[A-Za-z0-9_-]+$/;

  constructor(
    private readonly ticketValidationService: TicketValidationService,
    private readonly ticketRepo: RealtimeTicketRepository,
  ) {}

  async execute(dto: WebSocketConnectDto): Promise<WebSocketConnectResponse> {
    const ticket = (dto.ticket ?? '').trim();

    // Structural validation of the raw ticket string.
    const formatResult = this.ticketValidationService.validateFormat(ticket);
    if (!formatResult.ok) {
      return {
        ok: false,
        error: formatResult.error === 'MISSING_TICKET' ? 'MISSING_TICKET' : 'INVALID_TICKET',
      };
    }

    // Length + charset caps before any repository lookup (DoS guard).
    if (ticket.length > WebSocketConnectUseCase.MAX_TICKET_LENGTH) {
      return { ok: false, error: 'INVALID_TICKET' };
    }
    if (!WebSocketConnectUseCase.TICKET_RE.test(ticket)) {
      return { ok: false, error: 'INVALID_TICKET' };
    }

    const now = Date.now();

    // Atomic validation + consumption via the shared repository.
    const validation = await this.ticketRepo.validateAndConsume(ticket, now);
    if (!validation.valid) {
      switch (validation.error) {
        case 'INVALID_TICKET':
          return { ok: false, error: 'INVALID_TICKET' };
        case 'EXPIRED_TICKET':
          return { ok: false, error: 'EXPIRED_TICKET' };
        case 'ALREADY_USED_TICKET':
          return { ok: false, error: 'ALREADY_USED_TICKET' };
        default:
          return { ok: false, error: 'VALIDATION_FAILED' };
      }
    }

    const tenantId = validation.tenantId;
    if (!tenantId) {
      return { ok: false, error: 'VALIDATION_FAILED' };
    }

    return { ok: true, data: { tenantId } };
  }
}
