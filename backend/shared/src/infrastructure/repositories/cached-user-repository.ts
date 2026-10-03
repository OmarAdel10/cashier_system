import { inject, injectable } from 'tsyringe';
import { UserRepository } from '../../domain/repositories/user-repository';
import { Cache } from '../cache/memory-cache';

@injectable()
export class CachedUserRepository implements UserRepository {
  constructor(
    @inject('UserRepository') private readonly decorated: UserRepository,
    @inject('MemoryCache') private readonly cache: Cache<any>
  ) {}

  async upsert(user: { 
    tenantId: string; 
    email: string; 
    role: string; 
    displayName?: string | undefined; 
    createdAt: number; 
    lastLoginAt?: number | undefined; 
    lastOwnerLoginAt?: number | undefined 
  }): Promise<void> {
    await this.decorated.upsert(user);
    // Invalidate cache for this tenant's user data
    await this.cache.del(`user:${user.tenantId}`);
  }

  async findByTenantId(tenantId: string): Promise<{ 
    tenantId: string; 
    email: string; 
    role: string; 
    tier: string; 
    displayName: string; 
    createdAt: number; 
    lastLoginAt?: number | undefined; 
    lastOwnerLoginAt?: number | undefined 
  } | null> {
    // Try cache first
    const cached = await this.cache.get(`user:${tenantId}`);
    if (cached !== null) {
      return cached;
    }

    // Fetch from decorated repository
    const result = await this.decorated.findByTenantId(tenantId);
    
    // Map User entity to expected format and cache the result (cache for 5 minutes)
    if (result !== null) {
      const mappedResult = {
        tenantId: result.tenantId,
        email: result.email,
        role: result.role,
        tier: result.tier ?? 'starter', // Default tier if not set
        displayName: result.displayName ?? '', // Default displayName if not set
        createdAt: result.createdAt,
        lastLoginAt: result.lastLoginAt,
        lastOwnerLoginAt: result.lastOwnerLoginAt
      };
      await this.cache.set(`user:${tenantId}`, mappedResult, 300);
      return mappedResult;
    }
    
    return result;
  }
}