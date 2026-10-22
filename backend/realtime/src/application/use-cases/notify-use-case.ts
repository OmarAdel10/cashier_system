import type { BroadcastService } from '../../domain/services/broadcast-service';
import type { BroadcastRepository } from '../../domain/repositories/broadcast-repository';
import type { NotifyUseCaseDto, NotifyUseCaseResponse } from '../dtos/notify-use-case-dto';

/** Keys prohibited in broadcast data (prototype-pollution / XSS guard). */
const DATA_FORBIDDEN_KEYS = new Set(['__proto__', 'constructor', 'prototype']);

/** Strip prototype-pollution keys from a data object (one level deep). */
function sanitizeData(data: Record<string, unknown>): Record<string, unknown> {
  const clean: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(data)) {
    if (DATA_FORBIDDEN_KEYS.has(key)) continue;
    clean[key] = value;
  }
  return clean;
}

/**
 * Use case for fanning out a service-binding notify event to a tenant's
 * WebSocket sessions.
 *
 * Validates the request inputs, builds a canonical broadcast payload,
 * persists the broadcast event, and returns the result. The internal shared
 * secret is validated at the route boundary (index.ts `X-Internal-Secret`
 * check); this use case owns the business decision of whether and what to
 * broadcast. The actual WebSocket send is handled by the Durable Object
 * (presentation/infrastructure layer).
 */
export class NotifyUseCase {
  /**
   * Max broadcast payload size in bytes (JSON-encoded). Prevents oversized
   * messages from being persisted and fanned out to tenant sessions (DoS).
   */
  private static readonly MAX_DATA_BYTES = 64 * 1024;

  /** Allowed event types. Arbitrary strings are rejected (routing safety). */
  private static readonly ALLOWED_EVENTS = new Set([
    'sale',
    'session',
    'sync',
    'session_revoked',
  ]);

  /** Max tenantId length. */
  private static readonly MAX_TENANT_ID_LENGTH = 128;

  /** tenantId format: lowercase alphanumeric, hyphens, underscores only. */
  private static readonly TENANT_ID_RE = /^[a-z0-9_-]+$/;

  constructor(
    private readonly broadcastService: BroadcastService,
    private readonly broadcastRepo: BroadcastRepository,
  ) {}

  async execute(dto: NotifyUseCaseDto): Promise<NotifyUseCaseResponse> {
    // Validate tenantId: presence, format, length (cross-tenant routing key).
    const tenantId = dto.tenantId?.trim() ?? '';
    if (tenantId.length === 0) {
      return { ok: false, error: 'MISSING_TENANT' };
    }
    if (tenantId.length > NotifyUseCase.MAX_TENANT_ID_LENGTH) {
      return { ok: false, error: 'INVALID_TENANT' };
    }
    if (!NotifyUseCase.TENANT_ID_RE.test(tenantId)) {
      return { ok: false, error: 'INVALID_TENANT' };
    }

    // Validate event: presence, allowlist, charset.
    const event = dto.event?.trim() ?? '';
    if (event.length === 0) {
      return { ok: false, error: 'INVALID_EVENT' };
    }
    if (!NotifyUseCase.ALLOWED_EVENTS.has(event)) {
      return { ok: false, error: 'INVALID_EVENT' };
    }

    const now = Date.now();

    // Bound broadcast data size before any processing (DoS guard).
    const data = dto.data ?? {};
    const dataBytes = new TextEncoder().encode(JSON.stringify(data)).length;
    if (dataBytes > NotifyUseCase.MAX_DATA_BYTES) {
      return { ok: false, error: 'BROADCAST_FAILED' };
    }

    // Build the canonical broadcast payload (data sanitized for prototype-pollution / XSS guard).
    const payload = this.broadcastService.buildPayload(
      event,
      tenantId,
      sanitizeData(data),
      now,
    );

    // Policy: drop events that cannot be routed to a tenant DO.
    if (!this.broadcastService.shouldBroadcast(payload)) {
      return { ok: false, error: 'BROADCAST_DROPPED' };
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

    return { ok: true, data: { broadcastId, payload } };
  }
}
