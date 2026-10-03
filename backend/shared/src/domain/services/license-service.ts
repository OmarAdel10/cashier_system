/**
 * Domain service for license business logic.
 *
 * Encapsulates pure business rules related to license validation,
 * expiry checking, and device limit enforcement per pricing tier.
 *
 * @example
 * ```typescript
 * const licenseService: LicenseService = container.resolve('LicenseService');
 * const isExpired = licenseService.isExpired(license.graceEnd, Date.now());
 * const limit = licenseService.getDeviceLimit('pro'); // Returns 3
 * ```
 */
export interface LicenseService {
  /**
   * Checks if a license is expired based on grace period end.
   *
   * Lifetime licenses have graceEnd = 0 and never expire.
   * The grace period allows continued access after subscription end
   * for a configured window (typically 7 days).
   *
   * @param graceEnd - Grace period end timestamp (ms), 0 for lifetime
   * @param now - Current timestamp in milliseconds
   * @returns true if expired, false otherwise
   */
  isExpired(graceEnd: number, now: number): boolean;

  /**
   * Returns the maximum number of devices allowed for a pricing tier.
   *
   * Device limits by tier:
   * - starter: 1 device
   * - pro: 3 devices
   * - business: 10 devices
   * - unknown/default: 1 device (starter)
   *
   * @param tier - Pricing tier: 'starter' | 'pro' | 'business'
   * @returns Device limit
   */
  getDeviceLimit(tier: string): number;
}