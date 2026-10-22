import type { RealtimeTicketRepository } from '../../../../shared/src/domain/repositories/realtime-ticket-repository';
import type { TicketValidationService } from '../../domain/services/ticket-validation-service';
import type { WebSocketConnectDto, WebSocketConnectResponse } from '../dtos/websocket-connect-dto';

/**
 * Use case for authenticating a WebSocket connection via a short-lived ticket.
 *
 * Validates the ticket format, then atomically validates and consumes it
 * through the shared RealtimeTicketRepository (expiry, single-use, tenant
 * lookup). On success returns the tenantId used to route the WebSocket to
 * the tenant's Durable Object.
 */
export class WebSocketConnectUseCase {
  constructor(
    private readonly ticketValidationService: TicketValidationService,
    private readonly ticketRepo: RealtimeTicketRepository,
  ) {}

  async execute(dto: WebSocketConnectDto): Promise<WebSocketConnectResponse> {
    // Structural validation of the raw ticket string.
    const formatResult = this.ticketValidationService.validateFormat(dto.ticket ?? '');
    if (!formatResult.ok) {
      return {
        ok: false,
        error: formatResult.error === 'MISSING_TICKET' ? 'MISSING_TICKET' : 'INVALID_TICKET',
      };
    }

    const now = Date.now();

    // Atomic validation + consumption via the shared repository.
    const validation = await this.ticketRepo.validateAndConsume(formatResult.value, now);
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
