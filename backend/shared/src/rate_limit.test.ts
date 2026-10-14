/**
 * Login throttling (T17 / DAFTARI-97) — 10 attempts / 15 minutes, sliding,
 * evaluated independently per client IP AND per (tenant, username). The
 * limiter is pure policy over two counter reads, so these tests drive a real
 * in-memory attempt log to prove the window arithmetic instead of mocking
 * counts.
 */
import { faker } from '@faker-js/faker';
import { describe, expect, it } from 'vitest';
import {
  RATE_LIMIT_MAX_ATTEMPTS,
  RATE_LIMIT_WINDOW_MS,
  checkLoginRateLimit,
  type AuthAttemptWindow,
} from './rate_limit';

interface Attempt {
  ip: string;
  tenantId: string;
  username: string;
  at: number;
  successful: boolean;
}

/** Minimal stand-in for the three TursoDb auth_attempts helpers. */
class FakeAttemptDb {
  readonly attempts: Attempt[] = [];

  record(
    ip: string,
    tenantId: string,
    username: string,
    at: number,
    successful = false,
  ): void {
    this.attempts.push({ ip, tenantId, username, at, successful });
  }

  async recordAuthAttempt(
    ip: string,
    tenantId: string,
    username: string,
    at: number,
    successful = false,
  ): Promise<void> {
    this.record(ip, tenantId, username, at, successful);
  }

  async getLastAuthSuccessAt(tenantId: string, username: string): Promise<number | null> {
    const successes = this.attempts
      .filter((a) => a.tenantId === tenantId && a.username === username && a.successful)
      .map((a) => a.at);
    return successes.length ? Math.max(...successes) : null;
  }

  private window(rows: Attempt[], since: number): AuthAttemptWindow {
    const inWindow = rows.filter((a) => !a.successful && a.at > since);
    return {
      count: inWindow.length,
      oldestAt: inWindow.length ? Math.min(...inWindow.map((a) => a.at)) : null,
    };
  }

  async countAuthAttemptsByIp(ip: string, since: number): Promise<AuthAttemptWindow> {
    return this.window(this.attempts.filter((a) => a.ip === ip), since);
  }

  async countAuthAttemptsByAccount(
    tenantId: string,
    username: string,
    since: number,
  ): Promise<AuthAttemptWindow> {
    return this.window(
      this.attempts.filter((a) => a.tenantId === tenantId && a.username === username),
      since,
    );
  }
}

function freshDb(): FakeAttemptDb {
  return new FakeAttemptDb();
}

function asDb(fake: FakeAttemptDb): Parameters<typeof checkLoginRateLimit>[0] {
  return fake as unknown as Parameters<typeof checkLoginRateLimit>[0];
}

describe('checkLoginRateLimit — sliding window policy', () => {
  it('pins the policy constants at 10 attempts / 15 minutes', () => {
    expect(RATE_LIMIT_MAX_ATTEMPTS).toBe(10);
    expect(RATE_LIMIT_WINDOW_MS).toBe(15 * 60 * 1000);
  });

  it('allows attempts below the threshold', async () => {
    const d = freshDb();
    const now = 1_000_000;
    for (let i = 0; i < 9; i++) d.record('1.1.1.1', 't1', 'admin', now - i);
    const res = await checkLoginRateLimit(asDb(d), '1.1.1.1', 't1', 'admin', now);
    expect(res.allowed).toBe(true);
    expect(res.retryAfterMs).toBe(0);
  });

  it('the 11th attempt from one IP in 15 minutes is rejected', async () => {
    const d = freshDb();
    const now = 1_000_000;
    // Ten prior attempts from the SAME IP but DIFFERENT accounts: only the IP
    // dimension can catch this credential-stuffing shape.
    for (let i = 0; i < 10; i++) d.record('1.1.1.1', 't1', `user${i}`, now - i * 1000);
    const res = await checkLoginRateLimit(asDb(d), '1.1.1.1', 't1', 'admin', now);
    expect(res.allowed).toBe(false);
    expect(res.retryAfterMs).toBeGreaterThan(0);
    expect(res.retryAfterMs).toBeLessThanOrEqual(RATE_LIMIT_WINDOW_MS);
  });

  it('the (tenant, username) dimension throttles across many IPs', async () => {
    const d = freshDb();
    const now = 1_000_000;
    for (let i = 0; i < 10; i++) d.record(`10.0.0.${i}`, 't1', 'admin', now - i * 1000);
    const res = await checkLoginRateLimit(asDb(d), '203.0.113.9', 't1', 'admin', now);
    expect(res.allowed).toBe(false);
    expect(res.retryAfterMs).toBeGreaterThan(0);
  });

  it('attempts from a different IP are unaffected', async () => {
    const d = freshDb();
    const now = 1_000_000;
    for (let i = 0; i < 10; i++) d.record('1.1.1.1', 't1', `user${i}`, now - i * 1000);
    const res = await checkLoginRateLimit(asDb(d), '2.2.2.2', 't1', 'admin', now);
    expect(res.allowed).toBe(true);
  });

  it('a different tenant or username is unaffected by an account lock', async () => {
    const d = freshDb();
    const now = 1_000_000;
    for (let i = 0; i < 10; i++) d.record('1.1.1.1', 't1', 'admin', now - i * 1000);
    const res = await checkLoginRateLimit(asDb(d), '2.2.2.2', 't2', 'cashier', now);
    expect(res.allowed).toBe(true);
  });

  it('the window slides: attempts older than 15 minutes stop counting', async () => {
    const d = freshDb();
    const t0 = 1_000_000;
    for (let i = 0; i < 10; i++) d.record('1.1.1.1', 't1', 'admin', t0);
    const blocked = await checkLoginRateLimit(asDb(d), '1.1.1.1', 't1', 'admin', t0 + 1000);
    expect(blocked.allowed).toBe(false);
    const slid = await checkLoginRateLimit(
      asDb(d),
      '1.1.1.1',
      't1',
      'admin',
      t0 + RATE_LIMIT_WINDOW_MS + 1,
    );
    expect(slid.allowed).toBe(true);
  });

  it('retryAfterMs counts down as the oldest attempt ages out', async () => {
    const d = freshDb();
    const t0 = 1_000_000;
    for (let i = 0; i < 10; i++) d.record('1.1.1.1', 't1', 'admin', t0 + i * 1000);
    const now = t0 + 5_000;
    const res = await checkLoginRateLimit(asDb(d), '1.1.1.1', 't1', 'admin', now);
    expect(res.allowed).toBe(false);
    // Oldest in-window attempt is t0; its expiry is t0 + WINDOW_MS.
    expect(res.retryAfterMs).toBe(t0 + RATE_LIMIT_WINDOW_MS - now);
  });

  it('a successful login starts a new account failure window', async () => {
    const d = freshDb();
    const now = 1_000_000;
    // Nine account failures arrive from distinct IPs so the IP dimension
    // cannot mask whether the account window actually resets.
    for (let i = 0; i < 9; i++) {
      d.record(`10.0.0.${i}`, 't1', 'admin', now - 20_000 + i);
    }
    d.record('203.0.113.20', 't1', 'admin', now - 10_000, true);
    d.record('203.0.113.20', 't1', 'admin', now - 5_000);
    const res = await checkLoginRateLimit(asDb(d), '203.0.113.20', 't1', 'admin', now);
    expect(res).toEqual({ allowed: true, retryAfterMs: 0 });
  });

  it('a successful login does not erase failures from the same IP window', async () => {
    const d = freshDb();
    const now = 1_000_000;
    for (let i = 0; i < 9; i++) {
      d.record('203.0.113.20', 't1', 'admin', now - 20_000 + i);
    }
    d.record('203.0.113.20', 't1', 'admin', now - 10_000, true);
    d.record('203.0.113.20', 't1', 'admin', now - 5_000);
    const res = await checkLoginRateLimit(asDb(d), '203.0.113.20', 't1', 'admin', now);
    expect(res.allowed).toBe(false);
    // The oldest IP failure, not the post-success failure, controls the wait.
    expect(res.retryAfterMs).toBe((now - 20_000) + RATE_LIMIT_WINDOW_MS - now);
  });
});

describe('checkLoginRateLimit — deterministic fuzz schedules', () => {
  const seeds = [101, 202, 303];
  const operations = 100;
  const ip = '203.0.113.10';
  const tenantId = 'tenant-1';
  const username = 'owner';

  it.each(seeds)('seed %i keeps both bounded windows and success resets consistent', async (seed) => {
    faker.seed(seed);
    const db = freshDb();
    let now = 1_800_000_000_000;

    const expectedAllowed = () => {
      const since = now - RATE_LIMIT_WINDOW_MS;
      const lastSuccess = db.attempts
        .filter((attempt) =>
          attempt.tenantId === tenantId &&
          attempt.username === username &&
          attempt.successful)
        .reduce<number | null>((latest, attempt) =>
          latest === null || attempt.at > latest ? attempt.at : latest, null);
      const accountSince = Math.max(since, lastSuccess ?? since);
      const ipFailures = db.attempts.filter((attempt) =>
        attempt.ip === ip && !attempt.successful && attempt.at > since);
      const accountFailures = db.attempts.filter((attempt) =>
        attempt.tenantId === tenantId &&
        attempt.username === username &&
        !attempt.successful &&
        attempt.at > accountSince);
      return ipFailures.length < RATE_LIMIT_MAX_ATTEMPTS &&
        accountFailures.length < RATE_LIMIT_MAX_ATTEMPTS;
    };

    for (let operation = 0; operation < operations; operation += 1) {
      now += faker.number.int({
        min: 0,
        max: Math.floor(RATE_LIMIT_WINDOW_MS / 5),
      });
      const expected = expectedAllowed();
      const decision = await checkLoginRateLimit(asDb(db), ip, tenantId, username, now);

      expect(decision.allowed).toBe(expected);
      if (!expected) {
        expect(decision.retryAfterMs).toBeGreaterThan(0);
        expect(decision.retryAfterMs).toBeLessThanOrEqual(RATE_LIMIT_WINDOW_MS);
      } else {
        expect(decision.retryAfterMs).toBe(0);
        const successful = faker.number.int({ min: 0, max: 9 }) < 2;
        db.record(ip, tenantId, username, now, successful);
      }
    }
  });
});
