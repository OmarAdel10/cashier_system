import 'reflect-metadata';
import { describe, expect, it, vi } from 'vitest';
import { TursoAuthUserRepository } from './turso-auth-user-repository';
import type { TursoDb } from '../../turso';
import type { AuthUserRecord } from '../../types';

const record: AuthUserRecord = {
  tenantId: 'tenant-1',
  username: 'owner',
  passwordHash: 'hash',
  role: 'admin',
  displayName: 'Owner',
  mustChangePassword: 1,
  isActive: 0,
  failedAttempts: 2,
  lockedUntil: 3000,
  createdAt: 1000,
  updatedAt: 2000,
};

function createDb() {
  return {
    getAuthUser: vi.fn().mockResolvedValue(record),
    listAuthUsers: vi.fn().mockResolvedValue([record]),
    insertAuthUser: vi.fn().mockResolvedValue(undefined),
    updateAuthUser: vi.fn().mockResolvedValue(undefined),
    recordAuthFailure: vi.fn().mockResolvedValue(undefined),
    reserveLoginAttempt: vi.fn().mockResolvedValue(true),
    releaseLoginAttempt: vi.fn().mockResolvedValue(undefined),
    convertReservationToFailure: vi.fn().mockResolvedValue(undefined),
    resetAuthFailures: vi.fn().mockResolvedValue(undefined),
  } as unknown as TursoDb;
}

describe('TursoAuthUserRepository', () => {
  it('maps a valid role and every optional auth-user field', async () => {
    const db = createDb();
    const repository = new TursoAuthUserRepository(db);

    await expect(repository.findByTenantAndUsername('tenant-1', 'owner'))
      .resolves.toEqual(record);
    await expect(repository.listByTenant('tenant-1')).resolves.toEqual([record]);
  });

  it('rejects an invalid normalized role instead of coercing it', async () => {
    const db = createDb();
    vi.mocked(db.getAuthUser).mockResolvedValue({ ...record, role: 'owner' });
    const repository = new TursoAuthUserRepository(db);

    await expect(repository.findByTenantAndUsername('tenant-1', 'owner'))
      .rejects.toThrow('INVALID_AUTH_USER_ROLE');
  });

  it('delegates every write and reservation method to TursoDb', async () => {
    const db = createDb();
    const repository = new TursoAuthUserRepository(db);
    const patch = { isActive: 1, failedAttempts: 0 };

    await repository.create({
      tenantId: 'tenant-1',
      username: 'owner',
      passwordHash: 'hash',
      role: 'admin',
    });
    await repository.update('tenant-1', 'owner', patch);
    await repository.recordFailure('tenant-1', 'owner');
    await expect(repository.reserveLoginAttempt('tenant-1', 'owner')).resolves.toBe(true);
    await repository.releaseLoginAttempt('tenant-1', 'owner');
    await repository.convertReservationToFailure('tenant-1', 'owner');
    await repository.resetFailures('tenant-1', 'owner');

    expect(db.insertAuthUser).toHaveBeenCalledWith({
      tenantId: 'tenant-1',
      username: 'owner',
      passwordHash: 'hash',
      role: 'admin',
    });
    expect(db.updateAuthUser).toHaveBeenCalledWith('tenant-1', 'owner', patch);
    expect(db.recordAuthFailure).toHaveBeenCalledWith('tenant-1', 'owner');
    expect(db.reserveLoginAttempt).toHaveBeenCalledWith('tenant-1', 'owner');
    expect(db.releaseLoginAttempt).toHaveBeenCalledWith('tenant-1', 'owner');
    expect(db.convertReservationToFailure).toHaveBeenCalledWith('tenant-1', 'owner');
    expect(db.resetAuthFailures).toHaveBeenCalledWith('tenant-1', 'owner');
  });
});
