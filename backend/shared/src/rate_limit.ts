/**
 * Login throttling (T17 / DAFTARI-97): a 10-attempts / 15-minute sliding
 * window evaluated independently per client IP and per (tenant, username).
 *
 * Why two dimensions:
 *  - per IP stops one host spraying many accounts (credential stuffing);
 *  - per account stops a botnet spraying one account from many hosts.
 * Either dimension alone is trivially bypassed by the other attack shape.
 *
 * This module is pure policy over two counter reads (the persisted log lives
 * in the `auth_attempts` table, migration 004). It intentionally knows
 * nothing about HOW the IP is derived — the route passes the trusted client
 * IP. It is called BEFORE the password KDF so a throttled request pays no
 * derivation cost.
 *
 * TODO(DAFTARI-97): Turnstile challenge on the login surface is a separate
 * task (out of scope here); this limiter is the server-side backstop.
 */
import type { TursoDb } from './turso';

/** Failure budget inside one window, per dimension. */
export const RATE_LIMIT_MAX_ATTEMPTS = 10;
/** Sliding window length in milliseconds. */
export const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;

/** Count of attempts inside the window plus the oldest in-window timestamp. */
export interface AuthAttemptWindow {
  count: number;
  oldestAt: number | null;
}

export interface RateLimitDecision {
  allowed: boolean;
  /** Milliseconds until the window frees a slot; 0 when allowed. */
  retryAfterMs: number;
}

/**
 * Decides whether an attempt identified by (ip, tenantId, username) may
 * proceed at `now`. The caller records the attempt only when allowed, so a
 * rejected request cannot extend its own window.
 */
export async function checkLoginRateLimit(
  db: TursoDb,
  ip: string,
  tenantId: string,
  username: string,
  now: number,
): Promise<RateLimitDecision> {
  const since = now - RATE_LIMIT_WINDOW_MS;
  const [byIp, byAccount] = await Promise.all([
    db.countAuthAttemptsByIp(ip, since),
    db.countAuthAttemptsByAccount(tenantId, username, since),
  ]);

  // Report the dimension that actually tripped, so retry_after_ms reflects the
  // attempt that must age out rather than an arbitrary window length.
  const tripped =
    byAccount.count >= RATE_LIMIT_MAX_ATTEMPTS
      ? byAccount
      : byIp.count >= RATE_LIMIT_MAX_ATTEMPTS
        ? byIp
        : null;
  if (!tripped) return { allowed: true, retryAfterMs: 0 };

  const oldest = tripped.oldestAt ?? now;
  return {
    allowed: false,
    retryAfterMs: Math.max(0, oldest + RATE_LIMIT_WINDOW_MS - now),
  };
}
