import { inject, injectable } from 'tsyringe';
import { SessionRepository } from '../../domain/repositories/session-repository';
import { Session } from '../../domain/entities/session';
import { Cache } from '../cache/memory-cache';

/**
 * Caching decorator for SessionRepository.
 *
 * Caches frequently accessed session queries to reduce database load.
 * Critical session operations (insert, heartbeat, end) bypass cache
 * for strong consistency on writes.
 *
 * Cache keys:
 * - `session:active:{tenantId}` - All active sessions (1 min TTL)
 * - `session:active:pos:{tenantId}` - Active POS sessions (1 min TTL)
 * - `session:active:username:{tenantId}:{username}:{heartbeatSince}` - Username-specific (1 min TTL)
 * - `session:recent:{tenantId}:{limit}` - Recent sessions (2 min TTL)
 * - `session:live:web:{tenantId}:{sessionId}` - Live web session (30 sec TTL)
 *
 * @example
 * ```typescript
 * // In DI container registration:
 * container.register('SessionRepository', {
 *   useFactory: (c) => new CachedSessionRepository(
 *     c.resolve('TursoSessionRepository'),
 *     c.resolve('MemoryCache')
 *   )
 * });
 * ```
 */
@injectable()
export class CachedSessionRepository implements SessionRepository {
  constructor(
    @inject('SessionRepository') private readonly decorated: SessionRepository,
    @inject('MemoryCache') private readonly cache: Cache<any>
  ) {}

  async insert(session: Session): Promise<boolean> {
    const result = await this.decorated.insert(session);
    if (result) {
      // Invalidate active session caches for this tenant
      await this.invalidateActiveCaches(session.tenantId);
    }
    return result;
  }

  async admitPosSession(session: Session, limit: number): Promise<boolean> {
    const result = await this.decorated.admitPosSession(session, limit);
    if (result) {
      await this.invalidateActiveCaches(session.tenantId);
    }
    return result;
  }

  async heartbeat(sessionId: string, tenantId: string, at: number): Promise<boolean> {
    const result = await this.decorated.heartbeat(sessionId, tenantId, at);
    if (result) {
      // Invalidate caches that might contain this session
      await this.invalidateActiveCaches(tenantId);
      await this.cache.del(`session:live:web:${tenantId}:${sessionId}`);
    }
    return result;
  }

  async end(sessionId: string, tenantId: string, at: number): Promise<boolean> {
    const result = await this.decorated.end(sessionId, tenantId, at);
    if (result) {
      await this.invalidateActiveCaches(tenantId);
      await this.cache.del(`session:live:web:${tenantId}:${sessionId}`);
    }
    return result;
  }

  async endForTenant(sessionId: string, tenantId: string, at: number): Promise<void> {
    await this.decorated.endForTenant(sessionId, tenantId, at);
    await this.invalidateActiveCaches(tenantId);
    await this.cache.del(`session:live:web:${tenantId}:${sessionId}`);
  }

  async endForDevice(tenantId: string, deviceHwid: string, at: number): Promise<void> {
    await this.decorated.endForDevice(tenantId, deviceHwid, at);
    await this.invalidateActiveCaches(tenantId);
  }

  async getLiveWeb(tenantId: string, sessionId: string): Promise<Session | null> {
    const cacheKey = `session:live:web:${tenantId}:${sessionId}`;

    // Try cache first (short TTL for strong consistency)
    const cached = await this.cache.get(cacheKey);
    if (cached !== null) {
      return cached;
    }

    const result = await this.decorated.getLiveWeb(tenantId, sessionId);

    // Cache for 30 seconds
    if (result !== null) {
      await this.cache.set(cacheKey, result, 30);
    }

    return result;
  }

  async getActive(tenantId: string): Promise<Session[]> {
    const cacheKey = `session:active:${tenantId}`;

    const cached = await this.cache.get(cacheKey);
    if (cached !== null) {
      return cached;
    }

    const result = await this.decorated.getActive(tenantId);

    // Cache for 1 minute
    await this.cache.set(cacheKey, result, 60);

    return result;
  }

  async getActiveForUsername(tenantId: string, username: string, heartbeatSince: number): Promise<Session[]> {
    const cacheKey = `session:active:username:${tenantId}:${username}:${heartbeatSince}`;

    const cached = await this.cache.get(cacheKey);
    if (cached !== null) {
      return cached;
    }

    const result = await this.decorated.getActiveForUsername(tenantId, username, heartbeatSince);

    // Cache for 1 minute
    await this.cache.set(cacheKey, result, 60);

    return result;
  }

  async getRecent(tenantId: string, limit: number): Promise<Session[]> {
    const cacheKey = `session:recent:${tenantId}:${limit}`;

    const cached = await this.cache.get(cacheKey);
    if (cached !== null) {
      return cached;
    }

    const result = await this.decorated.getRecent(tenantId, limit);

    // Cache for 2 minutes
    await this.cache.set(cacheKey, result, 120);

    return result;
  }

  async endWebSessions(tenantId: string, username: string, at: number): Promise<void> {
    await this.decorated.endWebSessions(tenantId, username, at);
    await this.invalidateActiveCaches(tenantId);
  }

  async getActivePos(tenantId: string): Promise<Session[]> {
    const cacheKey = `session:active:pos:${tenantId}`;

    const cached = await this.cache.get(cacheKey);
    if (cached !== null) {
      return cached;
    }

    const result = await this.decorated.getActivePos(tenantId);

    // Cache for 1 minute
    await this.cache.set(cacheKey, result, 60);

    return result;
  }

  /**
   * Invalidates all active session caches for a tenant.
   * Called after any write operation that changes session state.
   */
  private async invalidateActiveCaches(tenantId: string): Promise<void> {
    await Promise.all([
      this.cache.del(`session:active:${tenantId}`),
      this.cache.del(`session:active:pos:${tenantId}`),
      // Note: username-specific caches have dynamic keys, would need
      // a more sophisticated invalidation strategy (e.g., cache tags)
      // For now, they expire naturally via TTL
    ]);
  }
}