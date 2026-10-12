/**
 * User session entity.
 *
 * Represents an active or historical user session for a tenant.
 * Sessions track both POS device sessions and web dashboard sessions.
 * Heartbeat mechanism ensures stale sessions are cleaned up.
 *
 * @example
 * ```typescript
 * const session: Session = {
 *   id: 'sess_1234567890_abc123',
 *   tenantId: 'tenant-123',
 *   deviceHwid: 'device-abc',
 *   username: 'cashier1',
 *   startedAt: Date.now() - 3600000,
 *   heartbeatAt: Date.now() - 60000,
 *   endedAt: undefined,
 *   source: 'pos'
 * };
 * ```
 */
export interface Session {
  /** Unique session identifier: 'sess_{timestamp}_{random}' */
  readonly id: string;
  /** Tenant this session belongs to */
  readonly tenantId: string;
  /** Hardware ID of the device (or 'web_{timestamp}' for web sessions) */
  readonly deviceHwid: string;
  /** Username for auth users, or device identifier for POS sessions */
  readonly username: string;
  /** Unix timestamp (ms) when session started */
  readonly startedAt: number;
  /** Unix timestamp (ms) of last heartbeat */
  readonly heartbeatAt: number;
  /** Unix timestamp (ms) when session ended (undefined = active) */
  readonly endedAt?: number;
  /** Session origin: 'pos' (device) or 'web' (dashboard) */
  readonly source?: 'pos' | 'web';
}