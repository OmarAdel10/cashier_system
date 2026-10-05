import { Session } from '../entities/session';

/**
 * Repository interface for user session management.
 *
 * Provides comprehensive session lifecycle operations including creation,
 * heartbeat tracking, conflict resolution, and querying. Supports both
 * POS device sessions and web dashboard sessions.
 *
 * @example
 * ```typescript
 * const sessionRepo: SessionRepository = container.resolve('SessionRepository');
 * const created = await sessionRepo.insert(session);
 * await sessionRepo.heartbeat('sess_123', 'tenant-123', Date.now());
 * const active = await sessionRepo.getActive('tenant-123');
 * ```
 */
export interface SessionRepository {
  /**
   * Inserts a new session.
   *
   * @param session - Session entity to insert
   * @returns true if inserted, false if session ID already exists
   */
  insert(session: Session): Promise<boolean>;

  /**
   * Attempts to admit a POS session respecting device limits.
   *
   * Only allows the session if active POS sessions for the tenant
   * are below the device limit. Used for device limit enforcement.
   *
   * @param session - Session entity to admit
   * @param limit - Maximum concurrent POS sessions allowed
   * @returns true if admitted, false if limit exceeded
   */
  admitPosSession(session: Session, limit: number): Promise<boolean>;

  /**
   * Updates session heartbeat timestamp.
   *
   * Called periodically by POS devices to indicate liveness.
   * Returns false if session not found or already ended.
   *
   * @param sessionId - Session identifier
   * @param tenantId - Tenant identifier (for validation)
   * @param at - Current timestamp in milliseconds
   * @returns true if heartbeat recorded, false if session not found/ended
   */
  heartbeat(sessionId: string, tenantId: string, at: number): Promise<boolean>;

  /**
   * Ends a specific session by ID.
   *
   * @param sessionId - Session identifier
   * @param tenantId - Tenant identifier (for validation)
   * @param at - End timestamp in milliseconds
   * @returns true if session was ended, false if not found
   */
  end(sessionId: string, tenantId: string, at: number): Promise<boolean>;

  /**
   * Ends a session by ID within a tenant (void return).
   *
   * @param sessionId - Session identifier
   * @param tenantId - Tenant identifier
   * @param at - End timestamp in milliseconds
   */
  endForTenant(sessionId: string, tenantId: string, at: number): Promise<void>;

  /**
   * Ends all active sessions for a specific device.
   *
   * Called when a device is unregistered or reset.
   *
   * @param tenantId - Tenant identifier
   * @param deviceHwid - Device hardware identifier
   * @param at - End timestamp in milliseconds
   */
  endForDevice(tenantId: string, deviceHwid: string, at: number): Promise<void>;

  /**
   * Gets a live web session by tenant and session ID.
   *
   * Only returns sessions with source='web' that are not ended.
   *
   * @param tenantId - Tenant identifier
   * @param sessionId - Session identifier
   * @returns Session entity or null if not found/ended
   */
  getLiveWeb(tenantId: string, sessionId: string): Promise<Session | null>;

  /**
   * Gets all active (non-ended) sessions for a tenant.
   *
   * @param tenantId - Tenant identifier
   * @returns Array of active Session entities
   */
  getActive(tenantId: string): Promise<Session[]>;

  /**
   * Gets active sessions for a specific username within a time window.
   *
   * Used for concurrent session conflict detection during login.
   * Only returns sessions with heartbeat newer than heartbeatSince.
   *
   * @param tenantId - Tenant identifier
   * @param username - Username to filter by
   * @param heartbeatSince - Minimum heartbeat timestamp (ms)
   * @returns Array of matching active Session entities
   */
  getActiveForUsername(tenantId: string, username: string, heartbeatSince: number): Promise<Session[]>;

  /**
   * Gets recent sessions for a tenant (for activity feed).
   *
   * @param tenantId - Tenant identifier
   * @param limit - Maximum number of sessions to return
   * @returns Array of recent Session entities (newest first)
   */
  getRecent(tenantId: string, limit: number): Promise<Session[]>;

  /**
   * Ends all unended web sessions for a username.
   *
   * Called at successful login to prevent stale dashboard sessions.
   * (Security measure per QA finding F1)
   *
   * @param tenantId - Tenant identifier
   * @param username - Username to filter by
   * @param at - End timestamp in milliseconds
   */
  endWebSessions(tenantId: string, username: string, at: number): Promise<void>;

  /**
   * Gets all active POS sessions for a tenant.
   *
   * Used for device limit counting.
   *
   * @param tenantId - Tenant identifier
   * @returns Array of active POS Session entities
   */
  getActivePos(tenantId: string): Promise<Session[]>;
}