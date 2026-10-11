import 'reflect-metadata';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { TursoUserRepository } from './turso-user-repository';
import type { TursoDb } from '../../turso';

describe('TursoUserRepository', () => {
  let db: {
    upsertUser: ReturnType<typeof vi.fn>;
    getUser: ReturnType<typeof vi.fn>;
  };
  let repository: TursoUserRepository;

  beforeEach(() => {
    db = {
      upsertUser: vi.fn().mockResolvedValue(undefined),
      getUser: vi.fn().mockResolvedValue(null),
    };
    repository = new TursoUserRepository(db as unknown as TursoDb);
  });

  it('passes the camelCase user profile through without transforming persistence fields', async () => {
    await repository.upsert({
      tenantId: 'tenant-1',
      email: 'owner@example.test',
      role: 'admin',
      displayName: 'Owner',
      createdAt: 123,
      lastLoginAt: 456,
      lastOwnerLoginAt: 789,
    });

    expect(db.upsertUser).toHaveBeenCalledWith({
      tenantId: 'tenant-1',
      email: 'owner@example.test',
      role: 'admin',
      tier: undefined,
      displayName: 'Owner',
      createdAt: 123,
      lastLoginAt: 456,
      lastOwnerLoginAt: 789,
    });
  });

  it('maps tier and optional profile fields from a database row', async () => {
    db.getUser.mockResolvedValue({
      tenantId: 'tenant-1',
      email: 'owner@example.test',
      role: 'admin',
      tier: 'business',
      displayName: 'Owner',
      createdAt: 123,
      lastLoginAt: 456,
      lastOwnerLoginAt: 789,
    });

    await expect(repository.findByTenantId('tenant-1')).resolves.toEqual({
      tenantId: 'tenant-1',
      email: 'owner@example.test',
      role: 'admin',
      tier: 'business',
      displayName: 'Owner',
      createdAt: 123,
      lastLoginAt: 456,
      lastOwnerLoginAt: 789,
    });
  });

  it('returns null when the tenant profile is absent', async () => {
    await expect(repository.findByTenantId('tenant-missing')).resolves.toBeNull();
    expect(db.getUser).toHaveBeenCalledWith('tenant-missing');
  });
});
