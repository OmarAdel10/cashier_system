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

  it('stays idempotent — a repeated call still returns ok', async () => {
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
});
