/**
 * Domain service for authentication business logic.
 *
 * Encapsulates pure business rules related to authentication that don't
 * belong to any single entity. This includes password validation,
 * session conflict detection, lockout calculation, and owner re-auth requirements.
 *
 * @example
 * ```typescript
 * const authService: AuthService = container.resolve('AuthService');
 * const isValid = await authService.validateCredentials('password123', 'pbkdf2-sha512$1000000$salt$hash');
 * const lockoutMs = authService.calculateLockout(5); // Returns lockout duration in ms
 * ```
 */
export interface AuthService {
  /**
   * Validates a plaintext password against a stored hash.
   *
   * Uses PBKDF2-SHA512 with 1,000,000 iterations to verify the password.
   * The hash format is: 'pbkdf2-sha512$iterations$salt_b64url$hash_b64url'
   *
   * @param password - Plaintext password to verify
   * @param passwordHash - Stored scheme-tagged hash
   * @returns true if password matches, false otherwise
   */
  validateCredentials(password: string, passwordHash: string): Promise<boolean>;

  /**
   * Determines if owner re-authentication (Firebase Stage-1) is required.
   *
   * Owner must re-authenticate if lastOwnerLoginAt is older than
   * the configured threshold (default: 30 days) or never set.
   *
   * @param lastOwnerLoginAt - Timestamp of last owner login (ms), undefined if never
   * @returns true if re-authentication required, false otherwise
   */
  shouldRequireOwnerReauth(lastOwnerLoginAt: number | undefined): boolean;

  /**
   * Checks if current sessions represent a conflict for new login.
   *
   * Currently returns false (allowing multiple concurrent sessions).
   * In stricter implementations, would return true if active sessions
   * exceed allowed concurrent limit for the user's role.
   *
   * @param currentSessions - Array of active session objects
   * @returns true if conflict detected, false otherwise
   */
  isSessionConflict(currentSessions: Array<{ id: string }>): boolean;

  /**
   * Calculates lockout duration based on failed attempt count.
   *
   * Implements exponential backoff:
   * - 1-3 attempts: no lockout (null)
   * - 4 attempts: 1 minute
   * - 5 attempts: 5 minutes
   * - 6 attempts: 15 minutes
   * - 7 attempts: 1 hour
   * - 8+ attempts: 24 hours
   *
   * @param failedAttempts - Number of consecutive failed attempts (after increment)
   * @returns Lockout duration in milliseconds, or null if no lockout
   */
  calculateLockout(failedAttempts: number): number | null;
}