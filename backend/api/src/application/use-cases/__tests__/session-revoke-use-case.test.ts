/**
 * SessionRevokeUseCase Tests
 *
 * Covers the revoke path, the SESSION_NOT_FOUND arm, the OWNER_ONLY contract
 * (not enforced at this layer), and dependency rejections.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SessionRevokeUseCase } from '../session-revoke-use-case';

const FIXED_NOW = 1_700_000_000_000;

const baseDto = {
  sessionId: 'sess-1',
  tenantId: 'tenant-1',
};

const makeSessionRepo = (ended = true) => ({
  end: vi.fn().mockResolvedValue(ended),
});

describe('SessionRevokeUseCase', () => {
  let sessionRepo: ReturnType<typeof makeSessionRepo>;
  let useCase: SessionRevokeUseCase;

  beforeEach(() => {
    sessionRepo = makeSessionRepo();
    useCase = new SessionRevokeUseCase(sessionRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('revokes the session for its own tenant at the pinned now timestamp', async () => {
    const result = await useCase.execute(baseDto);

    expect(sessionRepo.end).toHaveBeenCalledWith('sess-1', 'tenant-1', FIXED_NOW);
    expect(result).toEqual({ ok: true });
  });

  it('returns SESSION_NOT_FOUND when the session is not found', async () => {
    sessionRepo.end = vi.fn().mockResolvedValue(false);

    const result = await useCase.execute(baseDto);

    expect(result).toEqual({ ok: false, error: 'SESSION_NOT_FOUND' });
  });

  it('does not enforce OWNER_ONLY at the application layer (route concern)', async () => {
    // The use case ends the session regardless of the caller's ownership; the
    // route/middleware owns the owner vs. own-session check.
    const result = await useCase.execute({ sessionId: 'sess-9', tenantId: 'tenant-1' });

    expect(result).toEqual({ ok: true });
    expect(sessionRepo.end).toHaveBeenCalledWith('sess-9', 'tenant-1', FIXED_NOW);
  });

  it('revokes only the session for the tenant named by the dto', async () => {
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
