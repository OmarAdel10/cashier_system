/**
 * Data Transfer Object for a broadcast event to persist.
 *
 * Internal representation of an event fanned out to a tenant's WebSocket
 * sessions, produced by NotifyUseCase from a raw notify request.
 */
export interface BroadcastEventDto {
  /** Tenant this event targets. */
  readonly tenantId: string;
  /** Event type, e.g. 'sale' | 'session' | 'sync'. */
  readonly type: string;
  /** Event payload data (opaque passthrough). */
  readonly data: Record<string, unknown>;
  /** Unix timestamp (ms) when the event was created. */
  readonly createdAt: number;
}
