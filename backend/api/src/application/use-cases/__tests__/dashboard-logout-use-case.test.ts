/**
 * DashboardLogoutUseCase Tests
 *
 * Covers the idempotent logout path: the session named by the bearer token is
 * ended for its own tenant at the single pinned now timestamp.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { DashboardLogoutUseCase } from '../dashboard-logout-use-case';

const FIXED_NOW = 1_700_000_000_000;

const baseDto = {
  sessionId: 'sess-1',
  tenantId: 'tenant-1',
};

const makeSessionRepo = () => ({
  endForTenant: vi.fn().mockResolvedValue(undefined),
});

describe('DashboardLogoutUseCase', () => {
  let sessionRepo: ReturnType<typeof makeSessionRepo>;
  let useCase: DashboardLogoutUseCase;

  beforeEach(() => {
    sessionRepo = makeSessionRepo();
    useCase = new DashboardLogoutUseCase(sessionRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('ends the session for its own tenant at the pinned now timestamp', async () => {
    const result = await useCase.execute(baseDto);

    expect(sessionRepo.endForTenant).toHaveBeenCalledWith('sess-1', 'tenant-1', FIXED_NOW);
    expect(result).toEqual({ ok: true });
  });

  it('delegates endForTenant and resolves cleanly on repeat calls', async () => {
    // Real idempotence is owned by the repository (ended_at IS NULL predicate).
    await useCase.execute(baseDto);
    const second = await useCase.execute(baseDto);

    expect(second).toEqual({ ok: true });
    expect(sessionRepo.endForTenant).toHaveBeenCalledTimes(2);
    expect(sessionRepo.endForTenant).toHaveBeenNthCalledWith(
      2,
      'sess-1',
      'tenant-1',
      FIXED_NOW,
    );
  });

  it('ends only the session for the tenant named by the dto', async () => {
    await useCase.execute({ sessionId: 'sess-1', tenantId: 'tenant-2' });

    expect(sessionRepo.endForTenant).toHaveBeenCalledTimes(1);
    expect(sessionRepo.endForTenant).toHaveBeenCalledWith('sess-1', 'tenant-2', FIXED_NOW);
    expect(sessionRepo.endForTenant).not.toHaveBeenCalledWith('sess-1', 'tenant-1', FIXED_NOW);
  });

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    sessionRepo.endForTenant.mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });

  it('returns ok without touching the repo when sessionId is empty', async () => {
    const result = await useCase.execute({ sessionId: '', tenantId: 'tenant-1' });

    expect(result).toEqual({ ok: true });
    expect(sessionRepo.endForTenant).not.toHaveBeenCalled();
  });

  it('returns ok without touching the repo when tenantId is empty', async () => {
    const result = await useCase.execute({ sessionId: 'sess-1', tenantId: '' });

    expect(result).toEqual({ ok: true });
    expect(sessionRepo.endForTenant).not.toHaveBeenCalled();
  });
});
