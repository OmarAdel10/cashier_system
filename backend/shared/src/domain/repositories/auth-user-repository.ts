import { AuthUser } from '../entities/auth-user';

/**
 * Fields required to create a new auth user (without timestamps).
 * Timestamps are automatically set by the database layer.
 */
export interface NewAuthUser {
  /** Tenant this auth user belongs to */
  tenantId: string;
  /** Unique username within the tenant */
  username: string;
  /** PBKDF2-SHA512 password hash (scheme-tagged: algorithm$iters$salt$hash) */
  passwordHash: string;
  /** Role: 'admin' (tenant owner) or 'cashier' (staff) */
  role: 'admin' | 'cashier';
  /** Human-readable display name (optional) */
  displayName?: string;
  /** Whether password must be changed on next login (default: 0) */
  mustChangePassword?: number;
}

/**
 * Repository interface for cloud authentication users (admins/cashiers).
 *
 * Provides operations for auth user management including credential validation,
 * failure tracking with lockout, and concurrent login attempt handling.
 *
 * @example
 * ```typescript
 * const authUserRepo: AuthUserRepository = container.resolve('AuthUserRepository');
 * const user = await authUserRepo.findByTenantAndUsername('tenant-123', 'cashier1');
 * await authUserRepo.recordFailure('tenant-123', 'cashier1');
 * await authUserRepo.resetFailures('tenant-123', 'cashier1');
 * ```
 */
export interface AuthUserRepository {
  /**
   * Finds an auth user by tenant and username.
   *
   * @param tenantId - Tenant identifier
   * @param username - Username to search for
   * @returns AuthUser entity or null if not found
   */
  findByTenantAndUsername(tenantId: string, username: string): Promise<AuthUser | null>;

  /**
   * Lists all auth users for a tenant.
   *
   * @param tenantId - Tenant identifier
   * @returns Array of AuthUser entities
   */
  listByTenant(tenantId: string): Promise<AuthUser[]>;

  /**
   * Creates a new auth user.
   *
   * @param user - NewAuthUser data (without timestamps)
   * @returns Promise that resolves when operation completes
   */
  create(user: NewAuthUser): Promise<void>;

  /**
   * Updates an auth user with a partial patch.
   *
   * Cannot update tenantId, username, or createdAt.
   *
   * @param tenantId - Tenant identifier
   * @param username - Username to update
   * @param patch - Partial fields to update
   * @returns Promise that resolves when operation completes
   */
  update(tenantId: string, username: string, patch: Partial<Omit<AuthUser, 'tenantId' | 'username' | 'createdAt'>>): Promise<void>;

  /**
   * Records a failed login attempt and increments failure counter.
   *
   * Used for lockout tracking. Automatically handles lockout logic
   * based on failed attempt count.
   *
   * @param tenantId - Tenant identifier
   * @param username - Username that failed
   * @returns Promise that resolves when operation completes
   */
  recordFailure(tenantId: string, username: string): Promise<void>;

  /**
   * Reserves a login attempt slot (for concurrency control).
   *
   * Returns false if max concurrent attempts reached for this user.
   * Used to prevent brute-force parallel attempts.
   *
   * @param tenantId - Tenant identifier
   * @param username - Username attempting login
   * @returns true if slot reserved, false if limit reached
   */
  reserveLoginAttempt(tenantId: string, username: string): Promise<boolean>;

  /**
   * Releases a previously reserved login attempt slot.
   *
   * Called when login attempt completes (success or failure).
   *
   * @param tenantId - Tenant identifier
   * @param username - Username
   * @returns Promise that resolves when operation completes
   */
  releaseLoginAttempt(tenantId: string, username: string): Promise<void>;

  /**
   * Converts a reserved login attempt to a recorded failure.
   *
   * Called when a reserved attempt results in failed credentials.
   *
   * @param tenantId - Tenant identifier
   * @param username - Username
   * @returns Promise that resolves when operation completes
   */
  convertReservationToFailure(tenantId: string, username: string): Promise<void>;

  /**
   * Resets failed login attempts counter for a user.
   *
   * Called on successful login to clear lockout state.
   *
   * @param tenantId - Tenant identifier
   * @param username - Username
   * @returns Promise that resolves when operation completes
   */
  resetFailures(tenantId: string, username: string): Promise<void>;
}