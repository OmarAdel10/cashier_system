/**
 * Device Limit Service
 *
 * Encapsulates business logic for device limit enforcement based on
 * tenant pricing tier. Used by the session start use case to determine
 * how many concurrent POS sessions a tenant can have.
 */
import { TIER_DEVICE_LIMITS } from 'daftari-backend-shared/types';

/**
 * Determines the device limit for a given tier.
 * @param tier - The tenant's pricing tier ('starter', 'pro', 'business')
 * @returns Maximum number of concurrent POS sessions allowed
 */
export function getDeviceLimit(tier: string | undefined): number {
  return TIER_DEVICE_LIMITS[tier ?? 'starter'] ?? 1;
}

/**
 * Checks if a new POS session would exceed the device limit.
 * @param activeCount - Current number of active POS sessions
 * @param limit - Maximum allowed sessions for the tenant's tier
 * @returns true if the limit would be exceeded, false otherwise
 */
export function wouldExceedLimit(activeCount: number, limit: number): boolean {
  return activeCount >= limit;
}

/**
 * Gets the tier name for a given limit (inverse of getDeviceLimit).
 * Useful for display purposes.
 * @param limit - The device limit
 * @returns The tier name that corresponds to this limit
 */
export function getTierForLimit(limit: number): string {
  for (const [tier, tierLimit] of Object.entries(TIER_DEVICE_LIMITS)) {
    if (tierLimit === limit) return tier;
  }
  return 'starter';
}
