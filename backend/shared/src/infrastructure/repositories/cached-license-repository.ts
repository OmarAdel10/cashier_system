import { inject, injectable } from 'tsyringe';
import { LicenseRepository } from '../../domain/repositories/license-repository';
import { License } from '../../domain/entities/license';
import { Cache } from '../cache/memory-cache';

/**
 * Caching decorator for LicenseRepository.
 *
 * Caches license lookups by tenant to reduce database load for
 * frequently accessed license validation during session starts.
 *
 * Cache keys:
 * - `license:latest:{tenantId}` - Latest license for tenant (5 min TTL)
 * - `license:device:{tenantId}:{deviceHwid}` - Specific device license (5 min TTL)
 *
 * @example
 * ```typescript
 * // In DI container registration:
 * container.register('LicenseRepository', {
 *   useFactory: (c) => new CachedLicenseRepository(
 *     c.resolve('TursoLicenseRepository'),
 *     c.resolve('MemoryCache')
 *   )
 * });
 * ```
 */
@injectable()
export class CachedLicenseRepository implements LicenseRepository {
  constructor(
    @inject('LicenseRepository') private readonly decorated: LicenseRepository,
    @inject('MemoryCache') private readonly cache: Cache<any>
  ) {}

  async upsert(license: License): Promise<void> {
    await this.decorated.upsert(license);
    // Invalidate cache for this tenant's license data
    await this.cache.del(`license:latest:${license.tenantId}`);
    await this.cache.del(`license:device:${license.tenantId}:${license.deviceHwid}`);
  }

  async findByTenantAndDevice(tenantId: string, deviceHwid: string): Promise<License | null> {
    const cacheKey = `license:device:${tenantId}:${deviceHwid}`;

    // Try cache first
    const cached = await this.cache.get(cacheKey);
    if (cached !== null) {
      return cached;
    }

    // Fetch from decorated repository
    const result = await this.decorated.findByTenantAndDevice(tenantId, deviceHwid);

    // Cache the result (5 minutes)
    if (result !== null) {
      await this.cache.set(cacheKey, result, 300);
    }

    return result;
  }

  async findLatestByTenant(tenantId: string): Promise<License | null> {
    const cacheKey = `license:latest:${tenantId}`;

    // Try cache first
    const cached = await this.cache.get(cacheKey);
    if (cached !== null) {
      return cached;
    }

    // Fetch from decorated repository
    const result = await this.decorated.findLatestByTenant(tenantId);

    // Cache the result (5 minutes)
    if (result !== null) {
      await this.cache.set(cacheKey, result, 300);
    }

    return result;
  }

  async sweepExpired(now: number): Promise<void> {
    await this.decorated.sweepExpired(now);
    // Note: We don't cache sweep results, but we could invalidate
    // all license caches for affected tenants if needed
  }

  async isExpired(graceEnd: number, now: number): Promise<boolean> {
    // This is a pure computation, delegate directly
    return this.decorated.isExpired(graceEnd, now);
  }

  getDeviceLimit(tier: string): number {
    // This is a pure lookup, delegate directly
    return this.decorated.getDeviceLimit(tier);
  }
}