import { License } from '../entities/license';

/**
 * Repository interface for device licenses.
 *
 * Provides operations for license management including CRUD, expiry checking,
 * and device limit enforcement per pricing tier.
 *
 * @example
 * ```typescript
 * const licenseRepo: LicenseRepository = container.resolve('LicenseRepository');
 * await licenseRepo.upsert(license);
 * const latest = await licenseRepo.findLatestByTenant('tenant-123');
 * const isExpired = await licenseRepo.isExpired(license.graceEnd, Date.now());
 * const limit = licenseRepo.getDeviceLimit('pro'); // Returns 3
 * ```
 */
export interface LicenseRepository {
  /**
   * Creates or updates a license.
   *
   * @param license - License entity to persist
   * @returns Promise that resolves when operation completes
   */
  upsert(license: License): Promise<void>;

  /**
   * Finds a license by tenant and device hardware ID.
   *
   * @param tenantId - Tenant identifier
   * @param deviceHwid - Device hardware identifier
   * @returns License entity or null if not found
   */
  findByTenantAndDevice(tenantId: string, deviceHwid: string): Promise<License | null>;

  /**
   * Finds the most recent license for a tenant (by createdAt).
   *
   * Used for license validation during session start.
   *
   * @param tenantId - Tenant identifier
   * @returns Latest License entity or null if none exist
   */
  findLatestByTenant(tenantId: string): Promise<License | null>;

  /**
   * Marks expired licenses as 'expired' status.
   *
   * Should be called periodically (e.g., via cron) to clean up expired licenses.
   *
   * @param now - Current timestamp in milliseconds
   * @returns Promise that resolves when sweep completes
   */
  sweepExpired(now: number): Promise<void>;

  /**
   * Checks if a license is expired based on grace period end.
   *
   * Lifetime licenses have graceEnd = 0 and never expire.
   *
   * @param graceEnd - Grace period end timestamp (ms), 0 for lifetime
   * @param now - Current timestamp in milliseconds
   * @returns true if expired, false otherwise
   */
  isExpired(graceEnd: number, now: number): Promise<boolean>;

  /**
   * Returns the maximum number of devices allowed for a pricing tier.
   *
   * @param tier - Pricing tier: 'starter' | 'pro' | 'business'
   * @returns Device limit (starter=1, pro=3, business=10)
   */
  getDeviceLimit(tier: string): number;
}