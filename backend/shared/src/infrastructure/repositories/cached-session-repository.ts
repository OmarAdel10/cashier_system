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
 * - `session:username:{tenantId}:{username}` - Username-specific (30 sec TTL)
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
    @inject('TursoSessionRepository') private readonly decorated: SessionRepository,
    @inject('MemoryCache') private readonly cache: Cache<Session | Session[]>
  ) {}

  async insert(session: Session): Promise<boolean> {
    const result = await this.decorated.insert(session);
    if (result) {
      await this.invalidateSessionCaches();
    }
    return result;
  }

  async admitPosSession(session: Session, limit: number): Promise<boolean> {
    const result = await this.decorated.admitPosSession(session, limit);
    if (result) {
      await this.invalidateSessionCaches();
    }
    return result;
  }

  async heartbeat(sessionId: string, tenantId: string, at: number): Promise<boolean> {
    const result = await this.decorated.heartbeat(sessionId, tenantId, at);
    if (result) {
      await this.invalidateSessionCaches();
    }
    return result;
  }

  async end(sessionId: string, tenantId: string, at: number): Promise<boolean> {
    const result = await this.decorated.end(sessionId, tenantId, at);
    if (result) {
      await this.invalidateSessionCaches();
    }
    return result;
  }

  async endForTenant(sessionId: string, tenantId: string, at: number): Promise<void> {
    await this.decorated.endForTenant(sessionId, tenantId, at);
    await this.invalidateSessionCaches();
  }

  async endForDevice(tenantId: string, deviceHwid: string, at: number): Promise<void> {
    await this.decorated.endForDevice(tenantId, deviceHwid, at);
    await this.invalidateSessionCaches();
  }

  async getLiveWeb(tenantId: string, sessionId: string): Promise<Session | null> {
    const cacheKey = `session:live:web:${tenantId}:${sessionId}`;

    // Try cache first (short TTL for strong consistency)
    const cached = await this.cache.get(cacheKey);
    if (cached !== null && !Array.isArray(cached)) {
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
    if (cached !== null && Array.isArray(cached)) {
      return cached;
    }

    const result = await this.decorated.getActive(tenantId);

    // Cache for 1 minute
    await this.cache.set(cacheKey, result, 60);

    return result;
  }

  async getActiveForUsername(tenantId: string, username: string, heartbeatSince: number): Promise<Session[]> {
    // Stable key excludes heartbeatSince: the freshness filter is applied
    // per-request against the cached snapshot so a different freshness
    // window is never silently served.
    const cacheKey = `session:username:${tenantId}:${username}`;

    const cached = await this.cache.get(cacheKey);
    if (cached !== null && Array.isArray(cached)) {
      return this.filterByHeartbeat(cached, heartbeatSince);
    }

    // Always fetch the widest supported snapshot so later, narrower windows
    // can be served from this entry without needing another decorated call.
    const result = await this.decorated.getActiveForUsername(tenantId, username, 0);

    // Cache for 30 seconds (freshness-sensitive conflict detection)
    await this.cache.set(cacheKey, result, 30);

    return this.filterByHeartbeat(result, heartbeatSince);
  }

  async getRecent(tenantId: string, limit: number): Promise<Session[]> {
    const cacheKey = `session:recent:${tenantId}:${limit}`;

    const cached = await this.cache.get(cacheKey);
    if (cached !== null && Array.isArray(cached)) {
      return cached;
    }

    const result = await this.decorated.getRecent(tenantId, limit);

    // Cache for 2 minutes
    await this.cache.set(cacheKey, result, 120);

    return result;
  }

  async endWebSessions(tenantId: string, username: string, at: number): Promise<void> {
    await this.decorated.endWebSessions(tenantId, username, at);
    await this.invalidateSessionCaches();
  }

  async getActivePos(tenantId: string): Promise<Session[]> {
    const cacheKey = `session:active:pos:${tenantId}`;

    const cached = await this.cache.get(cacheKey);
    if (cached !== null && Array.isArray(cached)) {
      return cached;
    }

    const result = await this.decorated.getActivePos(tenantId);

    // Cache for 1 minute
    await this.cache.set(cacheKey, result, 60);

    return result;
  }

  /**
   * Invalidates all session cache families.
   * Called after any write operation that changes session state.
   */
  private async invalidateSessionCaches(): Promise<void> {
    await Promise.all([
      this.cache.invalidatePrefix('session:active:'),
      this.cache.invalidatePrefix('session:username:'),
      this.cache.invalidatePrefix('session:recent:'),
      this.cache.invalidatePrefix('session:live:web:'),
    ]);
  }

  /**
   * Applies the current freshness window to a cached or freshly
   * fetched username session snapshot (mirrors the DB filter
   * `heartbeat_at > ?`).
   */
  private filterByHeartbeat(sessions: Session[], heartbeatSince: number): Session[] {
    return sessions.filter((session) => session.heartbeatAt > heartbeatSince);
  }
}
