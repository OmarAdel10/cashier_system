/**
 * OwnerRefreshUseCase Tests
 *
 * Covers the find+upsert mirror: the full row is preserved and only
 * lastOwnerLoginAt is stamped; a missing row is a no-op that still returns ok.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { OwnerRefreshUseCase } from '../owner-refresh-use-case';

const FIXED_NOW = 1_700_000_000_000;

const makeUser = () => ({
  tenantId: 'tenant-1',
  email: 'owner@test.com',
  role: 'admin',
  tier: 'pro',
  displayName: 'Owner',
  createdAt: FIXED_NOW - 86_400_000,
  lastLoginAt: FIXED_NOW - 5_000,
  lastOwnerLoginAt: FIXED_NOW - 100_000,
});

const makeUserRepo = (user: ReturnType<typeof makeUser> | null = makeUser()) => ({
  findByTenantId: vi.fn().mockResolvedValue(user),
  upsert: vi.fn().mockResolvedValue(undefined),
});

describe('OwnerRefreshUseCase', () => {
  let userRepo: ReturnType<typeof makeUserRepo>;
  let useCase: OwnerRefreshUseCase;

  beforeEach(() => {
    userRepo = makeUserRepo();
    useCase = new OwnerRefreshUseCase(userRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('stamps lastOwnerLoginAt while preserving every other field', async () => {
    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(userRepo.findByTenantId).toHaveBeenCalledWith('tenant-1');
    expect(userRepo.upsert).toHaveBeenCalledWith({
      tenantId: 'tenant-1',
      email: 'owner@test.com',
      role: 'admin',
      tier: 'pro',
      displayName: 'Owner',
      createdAt: FIXED_NOW - 86_400_000,
      lastLoginAt: FIXED_NOW - 5_000,
      lastOwnerLoginAt: FIXED_NOW,
    });
    expect(result).toEqual({ ok: true });
  });

  it('upserts exactly once per refresh', async () => {
    await useCase.execute({ tenantId: 'tenant-1' });

    expect(userRepo.upsert).toHaveBeenCalledTimes(1);
  });

  it('is a silent no-op when the user row is missing', async () => {
    userRepo = makeUserRepo(null);
    useCase = new OwnerRefreshUseCase(userRepo as any);

    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(userRepo.findByTenantId).toHaveBeenCalledWith('tenant-1');
    expect(userRepo.upsert).not.toHaveBeenCalled();
    expect(result).toEqual({ ok: true });
  });
});
