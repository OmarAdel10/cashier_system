import 'reflect-metadata';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CachedLicenseRepository } from './cached-license-repository';
import { MemoryCache } from '../cache/memory-cache';
import type { LicenseRepository } from '../../domain/repositories/license-repository';
import type { License } from '../../domain/entities/license';

function makeLicense(overrides: Partial<License> = {}): License {
  return {
    tenantId: 't1',
    deviceHwid: 'hw1',
    licenseKey: 'signed-key',
    subscriptionEnd: 9999999999999,
    billingCycle: 'monthly',
    graceEnd: 9999999999999,
    status: 'active',
    createdAt: 1000,
    ...overrides,
  };
}

describe('CachedLicenseRepository', () => {
  let decorated: LicenseRepository;
  let cache: MemoryCache<License>;
  let repository: CachedLicenseRepository;

  beforeEach(() => {
    decorated = {
      upsert: vi.fn().mockResolvedValue(undefined),
      findByTenantAndDevice: vi.fn().mockResolvedValue(null),
      findLatestByTenant: vi.fn().mockResolvedValue(null),
      sweepExpired: vi.fn().mockResolvedValue(undefined),
      isExpired: vi.fn().mockResolvedValue(false),
      getDeviceLimit: vi.fn().mockReturnValue(1),
    };
    cache = new MemoryCache();
    repository = new CachedLicenseRepository(decorated, cache);
  });

  it('invalidates the license prefix after upsert', async () => {
    const license = makeLicense();
    vi.mocked(decorated.findByTenantAndDevice).mockResolvedValue(license);
    vi.mocked(decorated.findLatestByTenant).mockResolvedValue(license);

    await repository.findByTenantAndDevice('t1', 'hw1');
    await repository.findLatestByTenant('t1');
    expect(decorated.findByTenantAndDevice).toHaveBeenCalledTimes(1);
    expect(decorated.findLatestByTenant).toHaveBeenCalledTimes(1);

    await repository.upsert(license);

    await repository.findByTenantAndDevice('t1', 'hw1');
    await repository.findLatestByTenant('t1');
    expect(decorated.findByTenantAndDevice).toHaveBeenCalledTimes(2);
    expect(decorated.findLatestByTenant).toHaveBeenCalledTimes(2);
  });

  it('invalidates the license prefix after sweepExpired', async () => {
    const license = makeLicense();
    vi.mocked(decorated.findLatestByTenant).mockResolvedValue(license);

    await repository.findLatestByTenant('t1');
    expect(decorated.findLatestByTenant).toHaveBeenCalledTimes(1);

    await repository.sweepExpired(9999999999999);

    await repository.findLatestByTenant('t1');
    expect(decorated.findLatestByTenant).toHaveBeenCalledTimes(2);
  });
});
