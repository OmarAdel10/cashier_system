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
}

/**
 * Simple in-memory cache implementation with TTL support.
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
@injectable()
export class MemoryCache<T> implements Cache<T> {
  private store = new Map<string, { value: T; expires: number | null }>();

  /**
   * Retrieves a value from cache if not expired.
   *
   * @param key - Cache key
   * @returns Cached value or null if not found/expired
   */
  async get(key: string): Promise<T | null> {
    const item = this.store.get(key);
    if (!item) return null;

    // Check if expired
    if (item.expires !== null && Date.now() > item.expires) {
      this.store.delete(key);
      return null;
    }

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
    this.store.set(key, { value, expires });
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
}