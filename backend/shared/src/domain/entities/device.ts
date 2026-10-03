/**
 * POS device registration entity.
 *
 * Represents a physical POS device registered to a tenant.
 * Used for device limit enforcement and tracking device activity.
 *
 * @example
 * ```typescript
 * const device: Device = {
 *   tenantId: 'tenant-123',
 *   deviceHwid: 'device-abc',
 *   deviceName: 'Front Counter',
 *   platform: 'android',
 *   firstSeenAt: Date.now() - 86400000,
 *   lastSeenAt: Date.now()
 * };
 * ```
 */
export interface Device {
  /** Tenant this device belongs to */
  readonly tenantId: string;
  /** Unique hardware identifier for the device */
  readonly deviceHwid: string;
  /** Human-readable device name (e.g., 'Front Counter', 'Kitchen') */
  readonly deviceName?: string;
  /** Device platform: 'android', 'ios', 'windows', 'linux', 'web' */
  readonly platform?: string;
  /** Unix timestamp (ms) when device was first registered */
  readonly firstSeenAt: number;
  /** Unix timestamp (ms) of last heartbeat/activity */
  readonly lastSeenAt: number;
}