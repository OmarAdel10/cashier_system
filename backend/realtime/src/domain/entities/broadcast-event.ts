/**
 * BroadcastEvent entity.
 *
 * Represents an event pushed to the tenant's Durable Object by daftari-api
 * via service binding (/internal/notify). The DO fans the event out to every
 * live WebSocket session for that tenant.
 */
export interface BroadcastEvent {
  /** Unique event id (assigned at creation). */
  readonly id: string;
  /** Tenant this event targets. */
  readonly tenantId: string;
  /** Event type, e.g. 'sale' | 'session' | 'sync'. */
  readonly type: string;
  /** Event payload data. */
  readonly data: Record<string, unknown>;
  /** Unix timestamp (ms) when the event was created. */
  readonly createdAt: number;
}

/**
 * Input for creating a new BroadcastEvent.
 */
export interface NewBroadcastEvent {
  id: string;
  tenantId: string;
  type: string;
  data: Record<string, unknown>;
  createdAt: number;
}
