import { inject, injectable } from 'tsyringe';
import type { InValue } from '@libsql/client';
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
    const [lastSuccess, byIp, byAccount] = await Promise.all([
      this.getLastSuccessAt(tenantId, username),
      this.db.countAuthAttemptsByIp(ip, since),
      this.countAccountFailures(tenantId, username, since),
    ]);

    const accountWindowStart = Math.max(since, lastSuccess ?? since);
    const account = await this.countAccountFailures(tenantId, username, accountWindowStart);

    const tripped =
      account.count >= RATE_LIMIT_MAX_ATTEMPTS
        ? account
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

  private async getLastSuccessAt(
    tenantId: string,
    username: string,
  ): Promise<number | null> {
    const res = await this.db.exec(
      `SELECT MAX(attempted_at) AS last_success
       FROM auth_attempts
       WHERE tenant_id = ? AND username = ? AND successful = 1`,
      [tenantId, username],
    );
    const row = res.rows[0] as unknown as Record<string, unknown> | undefined;
    return row?.['last_success'] != null ? Number(row['last_success']) : null;
  }

  private async countAccountFailures(
    tenantId: string,
    username: string,
    since: number,
  ): Promise<{ count: number; oldestAt: number | null }> {
    const res = await this.db.exec(
      `SELECT COUNT(*) AS n, MIN(attempted_at) AS oldest
       FROM auth_attempts
       WHERE tenant_id = ? AND username = ? AND successful = 0 AND attempted_at > ?`,
      [tenantId, username, since] satisfies InValue[],
    );
    const row = res.rows[0] as unknown as Record<string, unknown> | undefined;
    return {
      count: Number(row?.['n'] ?? 0),
      oldestAt: row?.['oldest'] != null ? Number(row['oldest']) : null,
    };
  }
}
