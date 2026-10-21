/**
 * BroadcastPayload value object.
 *
 * Represents the event payload fanned out to a tenant's connected WebSocket
 * clients via the Durable Object hub.
 */
export interface BroadcastPayload {
  /** Event type, e.g. 'sale' | 'session' | 'sync'. */
  readonly type: string;
  /** Tenant this event belongs to. */
  readonly tenantId: string;
  /** Arbitrary event data (sale/session sync payload). */
  readonly data: Record<string, unknown>;
  /** Unix timestamp (ms) when the event was created. */
  readonly createdAt: number;
}
