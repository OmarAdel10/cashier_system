/**
 * SessionEndUseCase Tests
 *
 * Covers the idempotent end path (repository ends only `ended_at IS NULL`
 * rows), the SESSION_NOT_FOUND arm, and dependency rejections.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SessionEndUseCase } from '../session-end-use-case';

const FIXED_NOW = 1_700_000_000_000;

const baseDto = {
  sessionId: 'sess-1',
  tenantId: 'tenant-1',
};

const makeSessionRepo = (ended = true) => ({
  end: vi.fn().mockResolvedValue(ended),
});

describe('SessionEndUseCase', () => {
  let sessionRepo: ReturnType<typeof makeSessionRepo>;
  let useCase: SessionEndUseCase;

  beforeEach(() => {
    sessionRepo = makeSessionRepo();
    useCase = new SessionEndUseCase(sessionRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('ends the session for its own tenant at the pinned now timestamp', async () => {
    const result = await useCase.execute(baseDto);

    expect(sessionRepo.end).toHaveBeenCalledWith('sess-1', 'tenant-1', FIXED_NOW);
    expect(result).toEqual({ ok: true });
  });

  it('returns SESSION_NOT_FOUND when the session is not found', async () => {
    sessionRepo.end = vi.fn().mockResolvedValue(false);

    const result = await useCase.execute(baseDto);

    expect(result).toEqual({ ok: false, error: 'SESSION_NOT_FOUND' });
  });

  it('is idempotent: repeat calls end the same row again', async () => {
    await useCase.execute(baseDto);
    const second = await useCase.execute(baseDto);

    expect(second).toEqual({ ok: true });
    expect(sessionRepo.end).toHaveBeenCalledTimes(2);
    expect(sessionRepo.end).toHaveBeenNthCalledWith(2, 'sess-1', 'tenant-1', FIXED_NOW);
  });

  it('ends only the session for the tenant named by the dto', async () => {
    await useCase.execute({ sessionId: 'sess-1', tenantId: 'tenant-2' });

    expect(sessionRepo.end).toHaveBeenCalledTimes(1);
    expect(sessionRepo.end).toHaveBeenCalledWith('sess-1', 'tenant-2', FIXED_NOW);
    expect(sessionRepo.end).not.toHaveBeenCalledWith('sess-1', 'tenant-1', FIXED_NOW);
  });

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    sessionRepo.end = vi.fn().mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });
});
