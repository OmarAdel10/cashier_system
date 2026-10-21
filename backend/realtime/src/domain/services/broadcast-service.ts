import type { BroadcastPayload } from '../value-objects/broadcast-payload';

/**
 * Domain service for broadcast business rules.
 *
 * Encapsulates pure policy for constructing broadcast payloads and deciding
 * whether an event should be fanned out to a tenant's WebSocket sessions.
 */
export interface BroadcastService {
  /**
   * Builds a canonical BroadcastPayload from a raw notify event.
   *
   * @param type - Event type from the request body (e.g. 'sale' | 'session')
   * @param tenantId - Resolved tenant identifier (from verified context, never body)
   * @param data - Arbitrary event data from the request body
   * @param createdAt - Event creation timestamp in milliseconds
   * @returns the normalized payload
   */
  buildPayload(
    type: string,
    tenantId: string,
    data: Record<string, unknown>,
    createdAt: number,
  ): BroadcastPayload;

  /**
   * Decides whether a broadcast event should be fanned out to live sessions.
   *
   * @param payload - The broadcast payload to evaluate
   * @returns true if the event should be broadcast, false if it should be dropped
   */
  shouldBroadcast(payload: BroadcastPayload): boolean;
}
