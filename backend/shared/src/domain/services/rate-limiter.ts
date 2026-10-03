/**
 * Domain service for login rate limiting.
 *
 * Provides rate limiting functionality to prevent brute-force login attempts.
 * Tracks attempts per tenant/username combination with sliding window.
 *
 * @example
 * ```typescript
 * const rateLimiter: RateLimiter = container.resolve('RateLimiter');
 * const { allowed, retryAfterMs } = await rateLimiter.checkLimit('tenant-123', 'cashier1');
 * if (!allowed) {
 *   return { error: 'RATE_LIMITED', retryAfterMs };
 * }
 * await rateLimiter.recordAttempt('tenant-123', 'cashier1');
 * ```
 */
export interface RateLimiter {
  /**
   * Checks if a login attempt is allowed for the given tenant/username.
   *
   * Uses a sliding window algorithm with configurable limits:
   * - Max 5 attempts per minute
   * - Max 20 attempts per hour
   *
   * @param tenantId - Tenant identifier
   * @param username - Username attempting login
   * @returns Object with allowed flag and retryAfterMs (0 if allowed)
   */
  checkLimit(tenantId: string, username: string): Promise<{ allowed: boolean; retryAfterMs: number }>;

  /**
   * Records a login attempt (success or failure).
   *
   * Increments the attempt counters for the sliding window.
   *
   * @param tenantId - Tenant identifier
   * @param username - Username
   * @returns Promise that resolves when attempt is recorded
   */
  recordAttempt(tenantId: string, username: string): Promise<void>;

  /**
   * Resets all attempt counters for a tenant/username.
   *
   * Called on successful login to clear rate limit state.
   *
   * @param tenantId - Tenant identifier
   * @param username - Username
   * @returns Promise that resolves when counters are reset
   */
  resetAttempts(tenantId: string, username: string): Promise<void>;
}