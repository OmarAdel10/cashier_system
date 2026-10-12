/**
 * Domain service contract for login rate limiting.
 *
 * The limiter is failure-count based: a successful login starts a new account
 * failure window automatically. IP-level throttling intentionally does not get
 * reset by an individual account's success, preventing an attacker from using
 * one valid account to clear the credential-stuffing budget for an IP.
 */
export interface RateLimitDecision {
  allowed: boolean;
  /** Milliseconds until the oldest blocking failure ages out; 0 when allowed. */
  retryAfterMs: number;
}

export interface RateLimiter {
  /**
   * Decides whether an attempt identified by account and trusted client IP
   * may proceed at `now`. The caller records an attempt only when allowed.
   */
  checkLimit(
    tenantId: string,
    username: string,
    ip: string,
    now: number,
  ): Promise<RateLimitDecision>;

  /**
   * Records one admitted attempt outcome. Success resets the account failure
   * budget for subsequent checks; failures contribute to both dimensions.
   */
  recordAttempt(
    tenantId: string,
    username: string,
    ip: string,
    success: boolean,
    now: number,
  ): Promise<void>;
}
