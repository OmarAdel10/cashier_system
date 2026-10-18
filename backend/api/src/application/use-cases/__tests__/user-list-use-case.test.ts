/**
 * UserListUseCase Tests
 *
 * Covers user list mapping, 50-result cap, and missing-fields validation.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { UserListUseCase } from '../user-list-use-case';
import type { UserListDto } from '../../dtos/user-list.dto';
import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';

const FIXED_NOW = 1_700_000_000_000;

const baseDto: UserListDto = {
  tenantId: 'tenant-1',
};

const makeAuthUserRepo = (overrides: { listByTenant?: unknown } = {}) => ({
  listByTenant: vi.fn().mockResolvedValue(overrides.listByTenant ?? []),
});

describe('UserListUseCase', () => {
  let authUserRepo: ReturnType<typeof makeAuthUserRepo>;
  let useCase: UserListUseCase;

  beforeEach(() => {
    authUserRepo = makeAuthUserRepo();
    useCase = new UserListUseCase(authUserRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('returns the tenant auth users capped at 50', async () => {
    const users = Array.from({ length: 60 }, (_, i) => ({
      tenantId: 'tenant-1',
      username: `user${i}`,
      role: 'cashier',
      displayName: `User ${i}`,
      passwordHash: 'hash',
      mustChangePassword: 0,
      isActive: 1,
      failedAttempts: 0,
      createdAt: FIXED_NOW,
      updatedAt: FIXED_NOW,
    }));
    authUserRepo.listByTenant = vi.fn().mockResolvedValue(users);

    const result = await useCase.execute(baseDto);

    expect(authUserRepo.listByTenant).toHaveBeenCalledWith('tenant-1');
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.users).toHaveLength(50);
      expect(result.data.users[0]).toEqual({
        id: 'user0',
        username: 'user0',
        role: 'cashier',
        displayName: 'User 0',
        isActive: 1,
      });
    }
  });

  it('returns an empty list when the tenant has no users', async () => {
    authUserRepo.listByTenant = vi.fn().mockResolvedValue([]);

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.users).toEqual([]);
    }
  });

  it('returns MISSING_FIELDS for empty tenantId', async () => {
    const result = await useCase.execute({ ...baseDto, tenantId: '' });
    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('returns MISSING_FIELDS for whitespace-only tenantId', async () => {
    const result = await useCase.execute({ ...baseDto, tenantId: '   ' });
    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });
});
