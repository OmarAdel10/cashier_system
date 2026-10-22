/**
 * Simple fixed-window rate limiter (in-memory, temporary for Phase 3).
 * Replaced by a distributed rate limiter in Phase 4.
 */
export class RateLimiter {
  private readonly buckets = new Map<string, { count: number; resetAt: number }>();

  constructor(
    private readonly maxHits: number,
    private readonly windowMs: number,
  ) {}

  check(key: string): { allowed: boolean; retryAfterMs?: number } {
    const now = Date.now();
    let entry = this.buckets.get(key);
    if (!entry || now > entry.resetAt) {
      entry = { count: 1, resetAt: now + this.windowMs };
      this.buckets.set(key, entry);
      return { allowed: true };
    }
    if (entry.count >= this.maxHits) {
      return { allowed: false, retryAfterMs: entry.resetAt - now };
    }
    entry.count += 1;
    return { allowed: true };
  }
}
