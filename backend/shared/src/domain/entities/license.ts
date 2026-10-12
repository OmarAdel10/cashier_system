/**
 * Device license entity.
 *
 * Represents a license key bound to a specific device for a tenant.
 * Licenses control device access and enforce pricing tier limits.
 * The license key contains a signed payload with subscription details.
 *
 * @example
 * ```typescript
 * const license: License = {
 *   tenantId: 'tenant-123',
 *   deviceHwid: 'device-abc',
 *   licenseKey: 'signed-jwt-token...',
 *   subscriptionEnd: Date.now() + 30 * 24 * 60 * 60 * 1000,
 *   billingCycle: 'monthly',
 *   graceEnd: Date.now() + 37 * 24 * 60 * 60 * 1000, // 7-day grace
 *   status: 'active',
 *   createdAt: Date.now() - 86400000
 * };
 * ```
 */
export interface License {
  /** Tenant this license belongs to */
  readonly tenantId: string;
  /** Hardware ID of the licensed POS device */
  readonly deviceHwid: string;
  /** Opaque license key (JWT containing signed LicensePayload) */
  readonly licenseKey: string;
  /** Unix timestamp (ms) when the subscription period ends */
  readonly subscriptionEnd: number;
  /** Billing cycle: 'monthly' | 'yearly' | 'lifetime' */
  readonly billingCycle: 'monthly' | 'yearly' | 'lifetime';
  /** Unix timestamp (ms) when the grace period ends (0 for lifetime) */
  readonly graceEnd: number;
  /** Current license status: 'active' or 'expired' */
  readonly status: 'active' | 'expired';
  /** Unix timestamp (ms) when this license record was created */
  readonly createdAt: number;
}