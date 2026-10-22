import type { NewBroadcastEvent } from '../entities/broadcast-event';

/**
 * Repository interface for broadcast event persistence.
 *
 * Records events fanned out to a tenant's WebSocket clients so the event
 * history can be audited and replayed.
 */
export interface BroadcastRepository {
  /**
   * Inserts a new broadcast event.
   *
   * @param event - Event to insert
   * @returns true if inserted, false if an event with this id already exists
   */
  insert(event: NewBroadcastEvent): Promise<boolean>;

  /**
   * Gets recent broadcast events for a tenant (newest first).
   *
   * @param tenantId - Tenant identifier
   * @param limit - Maximum number of events to return
   * @returns Array of recent BroadcastEvent entities
   */
  getRecentForTenant(tenantId: string, limit: number): Promise<Array<NewBroadcastEvent>>;
}
