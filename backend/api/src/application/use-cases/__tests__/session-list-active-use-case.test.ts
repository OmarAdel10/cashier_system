/**
 * SessionListActiveUseCase Tests
 *
 * Covers listing active sessions for a tenant, the empty-list case, and
 * dependency rejections.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SessionListActiveUseCase } from '../session-list-active-use-case';

const FIXED_NOW = 1_700_000_000_000;

const baseDto = {
  tenantId: 'tenant-1',
};

const makeSessionRepo = (sessions: unknown[] = []) => ({
  getActive: vi.fn().mockResolvedValue(sessions),
});

describe('SessionListActiveUseCase', () => {
  let sessionRepo: ReturnType<typeof makeSessionRepo>;
  let useCase: SessionListActiveUseCase;

  beforeEach(() => {
    sessionRepo = makeSessionRepo();
    useCase = new SessionListActiveUseCase(sessionRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('lists active sessions for the tenant', async () => {
    const sessions = [
      { id: 'sess-1', tenantId: 'tenant-1', username: 'admin', source: 'web', startedAt: FIXED_NOW - 1000, heartbeatAt: FIXED_NOW },
      { id: 'sess-2', tenantId: 'tenant-1', username: 'cashier', source: 'pos', startedAt: FIXED_NOW - 2000, heartbeatAt: FIXED_NOW - 500 },
    ];
    sessionRepo.getActive = vi.fn().mockResolvedValue(sessions);

    const result = await useCase.execute(baseDto);

    expect(sessionRepo.getActive).toHaveBeenCalledWith('tenant-1');
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.sessions).toEqual([
        { sessionId: 'sess-1', username: 'admin', source: 'web', startedAt: FIXED_NOW - 1000, heartbeatAt: FIXED_NOW },
        { sessionId: 'sess-2', username: 'cashier', source: 'pos', startedAt: FIXED_NOW - 2000, heartbeatAt: FIXED_NOW - 500 },
      ]);
    }
  });

  it('returns all active sessions (no cap)', async () => {
    const sessions = Array.from({ length: 55 }, (_, i) => ({
      id: `sess-${i}`,
      tenantId: 'tenant-1',
      username: `user-${i}`,
      source: i % 2 === 0 ? 'web' : 'pos',
      startedAt: FIXED_NOW - i * 1000,
      heartbeatAt: FIXED_NOW,
    }));
    sessionRepo.getActive = vi.fn().mockResolvedValue(sessions);

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.sessions).toHaveLength(55);
      expect(result.data.sessions[0]?.sessionId).toBe('sess-0');
      expect(result.data.sessions[54]?.sessionId).toBe('sess-54');
    }
  });

  it('respects the display limit when one is provided', async () => {
    const sessions = Array.from({ length: 55 }, (_, i) => ({
      id: `sess-${i}`,
      tenantId: 'tenant-1',
      username: `user-${i}`,
      source: i % 2 === 0 ? 'web' : 'pos',
      startedAt: FIXED_NOW - i * 1000,
      heartbeatAt: FIXED_NOW,
    }));
    sessionRepo.getActive = vi.fn().mockResolvedValue(sessions);

    const result = await useCase.execute({ tenantId: 'tenant-1', limit: 2 });

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.sessions).toHaveLength(2);
      expect(result.data.sessions[0]?.sessionId).toBe('sess-0');
      expect(result.data.sessions[1]?.sessionId).toBe('sess-1');
    }
  });

  it('returns an ok with an empty list when there are no active sessions', async () => {
    sessionRepo.getActive = vi.fn().mockResolvedValue([]);

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.sessions).toEqual([]);
    }
  });

  it('maps undefined source to null', async () => {
    sessionRepo.getActive = vi.fn().mockResolvedValue([{ id: 'sess-1', tenantId: 'tenant-1', username: 'admin', startedAt: FIXED_NOW, heartbeatAt: FIXED_NOW }]);

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.sessions[0]?.source).toBe(null);
    }
  });

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    sessionRepo.getActive = vi.fn().mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });
});
