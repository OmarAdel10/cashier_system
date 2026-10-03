/**
 * Tenant owner/user profile entity.
 *
 * Represents a tenant's user profile in the system. This is distinct from
 * AuthUser which represents cloud authentication accounts (admin/cashier).
 * User profiles are created when a tenant is first set up and contain
 * display/pricing information.
 *
 * @example
 * ```typescript
 * const user: User = {
 *   tenantId: 'tenant-123',
 *   email: 'owner@example.com',
 *   role: 'admin',
 *   tier: 'pro',
 *   displayName: 'John Doe',
 *   createdAt: Date.now(),
 *   lastLoginAt: Date.now(),
 *   lastOwnerLoginAt: Date.now()
 * };
 * ```
 */
export interface User {
  /** Unique tenant identifier (UUID v4) */
  readonly tenantId: string;
  /** Owner's email address (used for login and notifications) */
  readonly email: string;
  /** Role within the tenant: 'admin' for owners, 'cashier' for staff (future) */
  readonly role: string;
  /** Pricing tier determining device limits: 'starter' | 'pro' | 'business' */
  readonly tier?: string;
  /** Human-readable display name for the owner */
  readonly displayName?: string;
  /** Unix timestamp (ms) when the tenant was created */
  readonly createdAt: number;
  /** Unix timestamp (ms) of the last successful login (any role) */
  readonly lastLoginAt?: number;
  /** Unix timestamp (ms) of the last owner (Firebase Stage-1) login */
  readonly lastOwnerLoginAt?: number;
}