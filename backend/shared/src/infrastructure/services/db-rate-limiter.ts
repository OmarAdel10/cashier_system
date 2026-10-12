import { inject, injectable } from 'tsyringe';
import { TursoDb } from '../../turso';
import {
  RATE_LIMIT_MAX_ATTEMPTS,
  RATE_LIMIT_WINDOW_MS,
} from '../../rate_limit';
import type { RateLimitDecision, RateLimiter } from '../../domain/services/rate-limiter';

/**
 * Turso-backed sliding-window limiter.
 *
 * Account failures are counted strictly after that account's most recent
 * successful login. IP failures are counted across the full sliding window so
 * a valid login cannot erase another account's stuffing evidence.
 */
@injectable()
export class DbRateLimiter implements RateLimiter {
  constructor(@inject('TursoDb') private readonly db: TursoDb) {}

  async checkLimit(
    tenantId: string,
    username: string,
    ip: string,
    now: number,
  ): Promise<RateLimitDecision> {
    const since = now - RATE_LIMIT_WINDOW_MS;
    const lastSuccess = await this.db.getLastAuthSuccessAt(tenantId, username);
    const accountSince = Math.max(since, lastSuccess ?? since);

    const [byIp, byAccount] = await Promise.all([
      this.db.countAuthAttemptsByIp(ip, since),
      this.db.countAuthAttemptsByAccount(tenantId, username, accountSince),
    ]);

    const tripped =
      byAccount.count >= RATE_LIMIT_MAX_ATTEMPTS
        ? byAccount
        : byIp.count >= RATE_LIMIT_MAX_ATTEMPTS
          ? byIp
          : null;
    if (!tripped) return { allowed: true, retryAfterMs: 0 };

    return {
      allowed: false,
      retryAfterMs: Math.max(0, (tripped.oldestAt ?? now) + RATE_LIMIT_WINDOW_MS - now),
    };
  }

  async recordAttempt(
    tenantId: string,
    username: string,
    ip: string,
    success: boolean,
    now: number,
  ): Promise<void> {
    await this.db.recordAuthAttempt(ip, tenantId, username, now, success);
  }

}
