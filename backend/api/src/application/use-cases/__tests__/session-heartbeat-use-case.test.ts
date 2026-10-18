/**
 * SessionHeartbeatUseCase Tests
 *
 * Covers the tenant-scoped heartbeat path, the SESSION_NOT_FOUND arm, and
 * dependency rejections.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SessionHeartbeatUseCase } from '../session-heartbeat-use-case';

const FIXED_NOW = 1_700_000_000_000;

const baseDto = {
  sessionId: 'sess-1',
  tenantId: 'tenant-1',
};

const makeSessionRepo = (recorded = true) => ({
  heartbeat: vi.fn().mockResolvedValue(recorded),
});

describe('SessionHeartbeatUseCase', () => {
  let sessionRepo: ReturnType<typeof makeSessionRepo>;
  let useCase: SessionHeartbeatUseCase;

  beforeEach(() => {
    sessionRepo = makeSessionRepo();
    useCase = new SessionHeartbeatUseCase(sessionRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('records the heartbeat at the pinned now timestamp and returns ok', async () => {
    const result = await useCase.execute(baseDto);

    expect(sessionRepo.heartbeat).toHaveBeenCalledWith('sess-1', 'tenant-1', FIXED_NOW);
    expect(result).toEqual({ ok: true });
  });

  it('returns SESSION_NOT_FOUND when the heartbeat is not recorded', async () => {
    sessionRepo.heartbeat = vi.fn().mockResolvedValue(false);

    const result = await useCase.execute(baseDto);

    expect(result).toEqual({ ok: false, error: 'SESSION_NOT_FOUND' });
  });

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    sessionRepo.heartbeat = vi.fn().mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });
});
