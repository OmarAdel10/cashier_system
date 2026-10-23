import type { NewWebSocketSession, WebSocketSession } from '../entities/websocket-session';

/**
 * Repository interface for WebSocket session lifecycle.
 *
 * Tracks active WebSocket sessions held by a tenant's Durable Object so
 * broadcasts can target live connections and stale sessions can be reaped.
 */
export interface WebSocketSessionRepository {
  /**
   * Records a newly accepted WebSocket session.
   *
   * @param session - Session to insert
   * @returns true if inserted, false if a session with this id already exists
   */
  insert(session: NewWebSocketSession): Promise<boolean>;

  /**
   * Marks a session as closed (no longer able to receive broadcasts).
   *
   * @param sessionId - Session identifier
   * @returns true if a session was closed, false if not found
   */
  close(sessionId: string): Promise<boolean>;

  /**
   * Updates a session's last-activity timestamp.
   *
   * @param sessionId - Session identifier
   * @param at - Activity timestamp in milliseconds
   * @returns true if updated, false if not found
   */
  heartbeat(sessionId: string, at: number): Promise<boolean>;

  /**
   * Gets all open sessions for a tenant (broadcast targets).
   *
   * @param tenantId - Tenant identifier
   * @returns Array of open WebSocketSession entities
   */
  getOpenForTenant(tenantId: string): Promise<WebSocketSession[]>;

  /**
   * Reaps sessions inactive beyond the staleness threshold.
   *
   * @param now - Current timestamp in milliseconds
   * @param staleAt - Sessions with lastActivityAt <= staleAt are closed
   * @returns Number of sessions closed
   */
  sweepStale(now: number, staleAt: number): Promise<number>;
}
