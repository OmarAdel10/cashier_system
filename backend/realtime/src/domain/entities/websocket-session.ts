/**
 * WebSocketSession entity.
 *
 * Represents an active WebSocket connection held by a tenant's Durable Object.
 * Sessions are hibernation-friendly: the DO owns them while cloudflare keeps
 * the socket open; the session record tracks liveness for broadcast targeting.
 */
export interface WebSocketSession {
  /** Unique session id assigned by the Durable Object on upgrade. */
  readonly id: string;
  /** Tenant this session belongs to (DO name = tenant uid). */
  readonly tenantId: string;
  /** Unix timestamp (ms) when the session was accepted. */
  readonly connectedAt: number;
  /** Unix timestamp (ms) of the last activity/heartbeat. */
  readonly lastActivityAt: number;
  /** Whether the socket is still open and able to receive broadcasts. */
  readonly isOpen: boolean;
}

/**
 * Input for recording a newly accepted WebSocket session.
 */
export interface NewWebSocketSession {
  id: string;
  tenantId: string;
  connectedAt: number;
}
