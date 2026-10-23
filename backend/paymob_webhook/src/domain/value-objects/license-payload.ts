/**
 * LicensePayload value object.
 *
 * Represents the signed license payload embedded inside an Ed25519 license
 * key. Computed from a webhook event plus the current time and billing
 * cycle subscription length.
 */
export interface LicensePayload {
  /** Tenant the license belongs to. */
  readonly tenantId: string;
  /** Hardware ID of the licensed device. */
  readonly deviceHwid: string;
  /** Unix timestamp (ms) when the subscription ends (0 for lifetime). */
  readonly subscriptionEnd: number;
  /** Billing cycle: 'monthly' | 'yearly' | 'lifetime'. */
  readonly billingCycle: 'monthly' | 'yearly' | 'lifetime';
  /** Unix timestamp (s) when the grace period ends (0 for lifetime). */
  readonly graceEnd: number;
  /** Unix timestamp (ms) when the license record was created. */
  readonly createdAt: number;
}

/**
 * Input for computing a LicensePayload from a webhook event.
 */
export interface NewLicensePayload {
  tenantId: string;
  deviceHwid: string;
  billingCycle: 'monthly' | 'yearly' | 'lifetime';
  now: number;
}
