import { inject, injectable } from 'tsyringe';
import { UserRepository } from '../../domain/repositories/user-repository';
import { User } from '../../domain/entities/user';
import { Cache } from '../cache/memory-cache';

@injectable()
export class CachedUserRepository implements UserRepository {
  constructor(
    @inject('TursoUserRepository') private readonly decorated: UserRepository,
    @inject('MemoryCache') private readonly cache: Cache<User>
  ) {}

  async upsert(user: User): Promise<void> {
    await this.decorated.upsert(user);
    // Invalidate all cached user data
    await this.cache.invalidatePrefix('user:');
  }

  async findByTenantId(tenantId: string): Promise<User | null> {
    // Try cache first
    const cached = await this.cache.get(`user:${tenantId}`);
    if (cached !== null) {
      return cached;
    }

    // Fetch from decorated repository
    const result = await this.decorated.findByTenantId(tenantId);
    
    // Cache the result (cache for 5 minutes)
    if (result !== null) {
      await this.cache.set(`user:${tenantId}`, result, 300);
    }
    
    return result;
  }
}
