import 'reflect-metadata';
import { describe, expect, it, vi } from 'vitest';
import type { TursoDb } from '../../turso';
import { DbRateLimiter } from './db-rate-limiter';

const WINDOW = 15 * 60 * 1000;
const NOW = 1_800_000_000_000;

function createLimiter(rows: Partial<TursoDb> = {}, execRows: Record<string, unknown>[] = []) {
  const db = {
    countAuthAttemptsByIp: vi.fn().mockResolvedValue({ count: 0, oldestAt: null }),
    countAuthAttemptsByAccount: vi.fn().mockResolvedValue({ count: 0, oldestAt: null }),
    recordAuthAttempt: vi.fn().mockResolvedValue(undefined),
    exec: (() => {
      let call = 0;
      return vi.fn().mockImplementation(async () => ({ rows: execRows[call++] ?? [] }));
    })(),
    ...rows,
  } as unknown as TursoDb;
  return { db, limiter: new DbRateLimiter(db) };
}

describe('DbRateLimiter', () => {
  it('allows an attempt below both failure budgets', async () => {
    const { db, limiter } = createLimiter({
      countAuthAttemptsByIp: vi.fn().mockResolvedValue({ count: 9, oldestAt: NOW - 1 }),
      countAuthAttemptsByAccount: vi.fn().mockResolvedValue({ count: 9, oldestAt: NOW - 2 }),
    });
    await expect(limiter.checkLimit('t1', 'user', '203.0.113.7', NOW)).resolves.toEqual({
      allowed: true,
      retryAfterMs: 0,
    });
    expect(db.countAuthAttemptsByIp).toHaveBeenCalledWith('203.0.113.7', NOW - WINDOW);
  });

  it('ignores account failures that precede the latest successful login', async () => {
    const lastSuccess = NOW - 5_000;
    const { db, limiter } = createLimiter(undefined, [{ last_success: lastSuccess }]);
    vi.spyOn(limiter as unknown as { getLastSuccessAt: () => Promise<number | null> }, 'getLastSuccessAt').mockResolvedValue(lastSuccess);
    await limiter.checkLimit('t1', 'user', '203.0.113.7', NOW);
    expect(db.exec).toHaveBeenLastCalledWith(
      expect.stringContaining('successful = 0'),
      ['t1', 'user', lastSuccess],
    );
  });

  it('reports account budget exhaustion and the retry interval', async () => {
    const oldest = NOW - 30_000;
    const { limiter } = createLimiter();
    vi.spyOn(
      limiter as unknown as {
        countAccountFailures: () => Promise<{ count: number; oldestAt: number | null }>;
      },
      'countAccountFailures',
    )
      .mockResolvedValueOnce({ count: 0, oldestAt: null })
      .mockResolvedValue({ count: 10, oldestAt: oldest });
    await expect(limiter.checkLimit('t1', 'user', '203.0.113.7', NOW)).resolves.toEqual({
      allowed: false,
      retryAfterMs: WINDOW - 30_000,
    });
  });

  it('reports IP budget exhaustion when the account budget is clean', async () => {
    const oldest = NOW - 60_000;
    const { limiter } = createLimiter({
      countAuthAttemptsByIp: vi.fn().mockResolvedValue({ count: 10, oldestAt: oldest }),
    });
    await expect(limiter.checkLimit('t1', 'user', '203.0.113.7', NOW)).resolves.toEqual({
      allowed: false,
      retryAfterMs: WINDOW - 60_000,
    });
  });

  it('records the explicit attempt outcome', async () => {
    const { db, limiter } = createLimiter();
    await limiter.recordAttempt('t1', 'user', '203.0.113.7', true, NOW);
    expect(db.recordAuthAttempt).toHaveBeenCalledWith('203.0.113.7', 't1', 'user', NOW, true);
  });
});
