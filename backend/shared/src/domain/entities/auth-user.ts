/**
 * Cloud authentication user entity.
 *
 * Represents an admin or cashier account in the cloud authentication system.
 * This is distinct from the User entity which represents the tenant owner profile.
 * AuthUser accounts are used for POS login and dashboard access.
 * Passwords are stored as PBKDF2-SHA512 hashes with 1,000,000 iterations.
 *
 * @example
 * ```typescript
 * const authUser: AuthUser = {
 *   tenantId: 'tenant-123',
 *   username: 'cashier1',
 *   passwordHash: 'pbkdf2-sha512$1000000$salt$hash',
 *   role: 'cashier',
 *   displayName: 'Front Counter',
 *   mustChangePassword: 0,
 *   isActive: 1,
 *   failedAttempts: 0,
 *   lockedUntil: undefined,
 *   createdAt: Date.now() - 86400000,
 *   updatedAt: Date.now() - 3600000
 * };
 * ```
 */
export interface AuthUser {
  /** Tenant this auth user belongs to */
  readonly tenantId: string;
  /** Unique username within the tenant */
  readonly username: string;
  /** PBKDF2-SHA512 password hash (scheme-tagged: algorithm$iters$salt$hash) */
  readonly passwordHash: string;
  /** Role: 'admin' (tenant owner) or 'cashier' (staff) */
  readonly role: 'admin' | 'cashier';
  /** Human-readable display name */
  readonly displayName?: string;
  /** Whether password must be changed on next login (0 = no, 1 = yes) */
  readonly mustChangePassword: number;
  /** Account active status (0 = disabled, 1 = active) */
  readonly isActive: number;
  /** Consecutive failed login attempts */
  readonly failedAttempts: number;
  /** Unix timestamp (ms) until which account is locked (undefined = not locked) */
  readonly lockedUntil?: number;
  /** Unix timestamp (ms) when this account was created */
  readonly createdAt: number;
  /** Unix timestamp (ms) when this account was last updated */
  readonly updatedAt: number;
}