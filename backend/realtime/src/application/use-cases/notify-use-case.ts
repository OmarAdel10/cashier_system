import type { BroadcastPayload } from '../../domain/value-objects/broadcast-payload';
import type { BroadcastRepository } from '../../domain/repositories/broadcast-repository';
import type { WebSocketSessionRepository } from '../../domain/repositories/websocket-session-repository';
import type { BroadcastService } from '../../domain/services/broadcast-service';
import type { NotifyUseCaseDto, NotifyUseCaseResponse } from '../dtos/notify-use-case-dto';

/**
 * Use case for fanning out a service-binding notify event to a tenant's
 * WebSocket sessions.
 *
 * Validates the request inputs, builds a canonical broadcast payload,
 * persists the broadcast event, and returns the result. The internal shared
 * secret is validated at the route boundary (Phase 3); this use case owns
 * the business decision of whether and what to broadcast. The actual WebSocket
 * send is handled by the Durable Object (presentation/infrastructure layer).
 */
export class NotifyUseCase {
  constructor(
    private readonly broadcastService: BroadcastService,
    private readonly broadcastRepo: BroadcastRepository,
    private readonly sessionRepo: WebSocketSessionRepository,
  ) {}

  async execute(dto: NotifyUseCaseDto): Promise<NotifyUseCaseResponse> {
    // Validate the request inputs.
    if (!dto.tenantId?.trim()) {
      return { ok: false, error: 'MISSING_TENANT' };
    }
    if (!dto.event?.trim()) {
      return { ok: false, error: 'INVALID_EVENT' };
    }

    const now = Date.now();

    // Build the canonical broadcast payload.
    const payload: BroadcastPayload = this.broadcastService.buildPayload(
      dto.event,
      dto.tenantId,
      dto.data ?? {},
      now,
    );

    // Policy: drop events that cannot be routed to a tenant DO.
    if (!this.broadcastService.shouldBroadcast(payload)) {
      return { ok: false, error: 'INVALID_EVENT' };
    }

    // Persist the broadcast event for audit/replay.
    const broadcastId = `bc_${now}_${crypto.randomUUID()}`;
    const inserted = await this.broadcastRepo.insert({
      id: broadcastId,
      tenantId: payload.tenantId,
      type: payload.type,
      data: payload.data,
      createdAt: payload.createdAt,
    });
    if (!inserted) {
      return { ok: false, error: 'BROADCAST_FAILED' };
    }

    return { ok: true, data: { broadcastId } };
  }
}
