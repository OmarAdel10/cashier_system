import 'reflect-metadata';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CachedSessionRepository } from './cached-session-repository';
import { MemoryCache } from '../cache/memory-cache';
import type { SessionRepository } from '../../domain/repositories/session-repository';
import type { Session } from '../../domain/entities/session';

function makeSession(overrides: Partial<Session> = {}): Session {
  return {
    id: 'sess-1',
    tenantId: 't1',
    deviceHwid: 'hw1',
    username: 'admin',
    startedAt: 1000,
    heartbeatAt: 5000,
    source: 'pos',
    ...overrides,
  };
}

describe('CachedSessionRepository', () => {
  let decorated: SessionRepository;
  let cache: MemoryCache<Session | Session[]>;
  let repository: CachedSessionRepository;

  beforeEach(() => {
    decorated = {
      insert: vi.fn().mockResolvedValue(true),
      admitPosSession: vi.fn().mockResolvedValue(true),
      heartbeat: vi.fn().mockResolvedValue(true),
      end: vi.fn().mockResolvedValue(true),
      endForTenant: vi.fn().mockResolvedValue(undefined),
      endForDevice: vi.fn().mockResolvedValue(undefined),
      getLiveWeb: vi.fn().mockResolvedValue(null),
      getActive: vi.fn().mockResolvedValue([]),
      getActiveForUsername: vi.fn().mockResolvedValue([]),
      getRecent: vi.fn().mockResolvedValue([]),
      endWebSessions: vi.fn().mockResolvedValue(undefined),
      getActivePos: vi.fn().mockResolvedValue([]),
    };
    cache = new MemoryCache();
    repository = new CachedSessionRepository(decorated, cache);
  });

  describe('stable username cache key', () => {
    it('serves the second username lookup from cache without embedding heartbeatSince', async () => {
      const sessions = [
        makeSession({ id: 's1', heartbeatAt: 6000 }),
        makeSession({ id: 's2', heartbeatAt: 2000 }),
      ];
      vi.mocked(decorated.getActiveForUsername).mockResolvedValue(sessions);

      const first = await repository.getActiveForUsername('t1', 'admin', 1000);
      const second = await repository.getActiveForUsername('t1', 'admin', 3000);

      expect(decorated.getActiveForUsername).toHaveBeenCalledTimes(1);
      expect(first.map((s) => s.id)).toEqual(['s1', 's2']);
      // Second call uses a different freshness window: served from the
      // cached snapshot but re-filtered so stale rows are excluded.
      expect(second.map((s) => s.id)).toEqual(['s1']);
    });

    it('does not create a distinct cache entry per heartbeatSince value', async () => {
      vi.mocked(decorated.getActiveForUsername).mockResolvedValue([]);

      await repository.getActiveForUsername('t1', 'admin', 1000);
      await repository.getActiveForUsername('t1', 'admin', 999999);
      await repository.getActiveForUsername('t1', 'admin', 42);

      // A single stable key serves every freshness window: the decorated
      // repository is called exactly once.
      expect(decorated.getActiveForUsername).toHaveBeenCalledTimes(1);
    });
  });

  describe('cache invalidation on writes', () => {
    it('invalidates all session cache families after insert', async () => {
      await repository.getActive('t1');
      await repository.getActivePos('t1');
      await repository.getRecent('t1', 5);
      await repository.getLiveWeb('t1', 'sess-1');
      await repository.getActiveForUsername('t1', 'admin', 1000);
      expect(decorated.getActive).toHaveBeenCalledTimes(1);
      expect(decorated.getActivePos).toHaveBeenCalledTimes(1);
      expect(decorated.getRecent).toHaveBeenCalledTimes(1);
      expect(decorated.getLiveWeb).toHaveBeenCalledTimes(1);
      expect(decorated.getActiveForUsername).toHaveBeenCalledTimes(1);

      await repository.insert(makeSession());

      await repository.getActive('t1');
      await repository.getActivePos('t1');
      await repository.getRecent('t1', 5);
      await repository.getLiveWeb('t1', 'sess-1');
      await repository.getActiveForUsername('t1', 'admin', 1000);
      expect(decorated.getActive).toHaveBeenCalledTimes(2);
      expect(decorated.getActivePos).toHaveBeenCalledTimes(2);
      expect(decorated.getRecent).toHaveBeenCalledTimes(2);
      expect(decorated.getLiveWeb).toHaveBeenCalledTimes(2);
      expect(decorated.getActiveForUsername).toHaveBeenCalledTimes(2);
    });

    it('invalidates all session cache families after end', async () => {
      await repository.getActive('t1');
      await repository.getActiveForUsername('t1', 'admin', 1000);

      await repository.end('sess-1', 't1', 9000);

      await repository.getActive('t1');
      await repository.getActiveForUsername('t1', 'admin', 1000);
      expect(decorated.getActive).toHaveBeenCalledTimes(2);
      expect(decorated.getActiveForUsername).toHaveBeenCalledTimes(2);
    });

    it('invalidates all session cache families after endForTenant', async () => {
      await repository.getRecent('t1', 5);

      await repository.endForTenant('sess-1', 't1', 9000);

      await repository.getRecent('t1', 5);
      expect(decorated.getRecent).toHaveBeenCalledTimes(2);
    });

    it('invalidates all session cache families after endWebSessions', async () => {
      await repository.getLiveWeb('t1', 'sess-1');

      await repository.endWebSessions('t1', 'admin', 9000);

      await repository.getLiveWeb('t1', 'sess-1');
      expect(decorated.getLiveWeb).toHaveBeenCalledTimes(2);
    });
  });
});
