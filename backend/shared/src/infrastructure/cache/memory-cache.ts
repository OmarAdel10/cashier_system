/**
 * Cache interface for repository caching decorators.
 * Implementations can be swapped (in-memory, Redis, etc.)
 *
 * @typeParam T - Type of cached values
 */
export interface Cache<T> {
  /**
   * Retrieves a value from cache.
   * @param key - Cache key
   * @returns Cached value or null if not found/expired
   */
  get(key: string): Promise<T | null>;

  /**
   * Stores a value in cache.
   * @param key - Cache key
   * @param value - Value to cache
   * @param ttlSeconds - Optional time-to-live in seconds
   */
  set(key: string, value: T, ttlSeconds?: number): Promise<void>;

  /**
   * Deletes a value from cache.
   * @param key - Cache key
   */
  del(key: string): Promise<void>;

  /**
   * Clears all cached values.
   */
  clear(): Promise<void>;

  /**
   * Deletes every cached value whose key starts with the given prefix.
   * @param prefix - Key prefix to invalidate
   */
  invalidatePrefix(prefix: string): Promise<void>;
}

/**
 * Simple bounded in-memory cache with TTL and LRU eviction. The bound is an
 * entry-count bound, not a byte-level memory bound.
 * Suitable for development and can be replaced with Redis/etc. in production.
 *
 * @example
 * ```typescript
 * const cache = new MemoryCache<string>();
 * await cache.set('key', 'value', 300); // 5-minute TTL
 * const value = await cache.get('key');
 * await cache.del('key');
 * ```
 * @typeParam T - Type of cached values
 */
import { injectable } from 'tsyringe';

/** Default maximum number of entries retained by MemoryCache. */
const DEFAULT_MAX_ENTRIES = 1000;

@injectable()
export class MemoryCache<T> implements Cache<T> {
  private store = new Map<string, { value: T; expires: number | null }>();
  private readonly maxEntries: number;

  /**
   * @param maxEntries - Maximum number of entries before LRU eviction
   *   (default 1000). Non-finite and non-positive values use the default.
   */
  constructor(maxEntries: number = DEFAULT_MAX_ENTRIES) {
    const requestedEntries = Number.isFinite(maxEntries) ? Math.floor(maxEntries) : DEFAULT_MAX_ENTRIES;
    this.maxEntries = requestedEntries > 0 ? requestedEntries : DEFAULT_MAX_ENTRIES;
  }

  /**
   * Retrieves a value from cache if not expired.
   *
   * @param key - Cache key
   * @returns Cached value or null if not found/expired
   */
  async get(key: string): Promise<T | null> {
    const item = this.store.get(key);
    if (!item) return null;

    if (item.expires !== null && Date.now() > item.expires) {
      this.store.delete(key);
      return null;
    }

    // Refresh LRU order: move key to most-recently-used position
    this.store.delete(key);
    this.store.set(key, item);

    return item.value;
  }

  /**
   * Stores a value in cache with optional TTL.
   *
   * @param key - Cache key
   * @param value - Value to cache
   * @param ttlSeconds - Time-to-live in seconds (undefined = no expiration)
   */
  async set(key: string, value: T, ttlSeconds?: number): Promise<void> {
    const expires = ttlSeconds !== undefined
      ? Date.now() + (ttlSeconds * 1000)
      : null;
    // Refresh LRU order: move key to most-recently-used position
    this.store.delete(key);
    this.store.set(key, { value, expires });
    this.evictLeastRecentlyUsed();
  }

  /**
   * Deletes a value from cache.
   *
   * @param key - Cache key to delete
   */
  async del(key: string): Promise<void> {
    this.store.delete(key);
  }

  /**
   * Clears all cached values.
   */
  async clear(): Promise<void> {
    this.store.clear();
  }

  /**
   * Deletes every cached value whose key starts with the given prefix.
   *
   * @param prefix - Key prefix to delete
   */
  async invalidatePrefix(prefix: string): Promise<void> {
    for (const key of Array.from(this.store.keys())) {
      if (key.startsWith(prefix)) {
        this.store.delete(key);
      }
    }
  }

  /**
   * Evicts least-recently-used entries while above the configured bound.
   */
  private evictLeastRecentlyUsed(): void {
    while (this.store.size > this.maxEntries) {
      const oldestKey = this.store.keys().next().value;
      if (oldestKey === undefined) break;
      this.store.delete(oldestKey);
    }
  }
}
