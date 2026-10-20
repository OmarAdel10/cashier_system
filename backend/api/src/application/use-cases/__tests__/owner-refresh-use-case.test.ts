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

type UserRow = ReturnType<typeof makeUser>;
type UserRowWithoutOptionalFields = Pick<UserRow, 'tenantId' | 'email' | 'role' | 'createdAt'>;

const makeUserRepo = (
  user: UserRow | UserRowWithoutOptionalFields | null = makeUser(),
) => ({
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

  it('does not add or drop keys on a row without optional fields', async () => {
    // Impl-level atomicity/lost-update (find + full-row upsert vs the legacy
    // single-column UPDATE) is deferred to Phase 6.
    const minimalRow = {
      tenantId: 'tenant-1',
      email: 'owner@test.com',
      role: 'admin',
      createdAt: FIXED_NOW - 86_400_000,
    };
    const snapshot = { ...minimalRow };
    userRepo = makeUserRepo(minimalRow);
    useCase = new OwnerRefreshUseCase(userRepo as any);

    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(userRepo.upsert).toHaveBeenCalledTimes(1);
    expect(userRepo.upsert).toHaveBeenCalledWith({
      ...minimalRow,
      lastOwnerLoginAt: FIXED_NOW,
    });
    const payload = userRepo.upsert.mock.calls[0]?.[0] as Record<string, unknown>;
    expect(Object.keys(payload).sort()).toEqual([
      'createdAt',
      'email',
      'lastOwnerLoginAt',
      'role',
      'tenantId',
    ]);
    expect(minimalRow).toEqual(snapshot);
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

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    userRepo.findByTenantId.mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute({ tenantId: 'tenant-1' })).rejects.toThrow('db down');
  });

  it('reads the clock after the awaited lookup (post-read now)', async () => {
    userRepo.findByTenantId.mockImplementationOnce(async () => {
      vi.setSystemTime(FIXED_NOW + 5_000);
      return makeUser();
    });

    await useCase.execute({ tenantId: 'tenant-1' });

    expect(userRepo.upsert).toHaveBeenCalledWith({
      ...makeUser(),
      lastOwnerLoginAt: FIXED_NOW + 5_000,
    });
  });

  it('propagates upsert rejections instead of resolving an error arm', async () => {
    userRepo.upsert.mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute({ tenantId: 'tenant-1' })).rejects.toThrow('db down');
  });

  it('returns ok:true when insert is refused', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue(makeUser());
    userRepo.upsert = vi.fn().mockResolvedValue(false);

    const result = await useCase.execute({ tenantId: 'tenant-1' });
    expect(result).toEqual({ ok: true });
  });
});
