/**
 * Simple fixed-window rate limiter (in-memory, temporary for Phase 4).
 * Replaced by a distributed rate limiter in Phase 5/6.
 *
 * Known limitation: buckets are per-Worker-instance and bypassable across
 * Cloudflare Worker instances. Mitigated by low maxHits default (100/min).
 * Cross-instance enforcement requires Phase 5/6 distributed rate limiter.
 */
export class RateLimiter {
  private readonly buckets = new Map<string, { count: number; resetAt: number }>();

  constructor(
    private readonly maxHits: number,
    private readonly windowMs: number,
    private readonly ttlMs: number = windowMs,
  ) {}

  check(key: string): { allowed: boolean; retryAfterMs?: number } {
    const now = Date.now();
    this.sweep(now);

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

  /** Remove expired buckets to prevent unbounded memory growth. */
  sweep(now: number = Date.now()): void {
    for (const [key, entry] of this.buckets) {
      if (now > entry.resetAt + this.ttlMs) {
        this.buckets.delete(key);
      }
    }
  }
}
