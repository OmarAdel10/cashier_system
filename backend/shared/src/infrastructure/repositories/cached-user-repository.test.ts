import 'reflect-metadata';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CachedUserRepository } from './cached-user-repository';
import { MemoryCache } from '../cache/memory-cache';
import type { UserRepository } from '../../domain/repositories/user-repository';
import type { User } from '../../domain/entities/user';

function makeUser(overrides: Partial<User> = {}): User {
  return {
    tenantId: 't1',
    email: 'owner@example.test',
    role: 'admin',
    createdAt: 1000,
    ...overrides,
  };
}

describe('CachedUserRepository', () => {
  let decorated: UserRepository;
  let cache: MemoryCache<User>;
  let repository: CachedUserRepository;

  beforeEach(() => {
    decorated = {
      upsert: vi.fn().mockResolvedValue(undefined),
      findByTenantId: vi.fn().mockResolvedValue(null),
    };
    cache = new MemoryCache();
    repository = new CachedUserRepository(decorated, cache);
  });

  it('invalidates the user prefix after upsert', async () => {
    const user = makeUser();
    vi.mocked(decorated.findByTenantId).mockResolvedValue(user);

    await repository.findByTenantId('t1');
    expect(decorated.findByTenantId).toHaveBeenCalledTimes(1);

    await repository.upsert(user);

    await repository.findByTenantId('t1');
    expect(decorated.findByTenantId).toHaveBeenCalledTimes(2);
  });
});
