import 'reflect-metadata';
import { faker } from '@faker-js/faker';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { MemoryCache } from './memory-cache';

describe('MemoryCache', () => {
  describe('constructor validation', () => {
    it.each([
      ['zero', 0],
      ['negative', -1],
      ['a positive fraction', 0.5],
      ['NaN', Number.NaN],
      ['positive infinity', Number.POSITIVE_INFINITY],
    ])('uses the safe default for %s maxEntries', async (_label, maxEntries) => {
      const cache = new MemoryCache<string>(maxEntries);
      for (let i = 0; i < 1001; i += 1) {
        await cache.set(`key-${i}`, String(i));
      }

      expect(await cache.get('key-0')).toBeNull();
      expect(await cache.get('key-1000')).toBe('1000');
    });
  });

  describe('LRU eviction', () => {
    it('evicts the least recently used entry beyond the configured bound', async () => {
      const cache = new MemoryCache<string>(3);
      await cache.set('a', '1');
      await cache.set('b', '2');
      await cache.set('c', '3');

      // Touch 'a' so 'b' becomes the least recently used entry
      expect(await cache.get('a')).toBe('1');

      await cache.set('d', '4');

      expect(await cache.get('a')).toBe('1');
      expect(await cache.get('b')).toBeNull();
      expect(await cache.get('c')).toBe('3');
      expect(await cache.get('d')).toBe('4');
    });

    it('evicts in insertion order when no entries were read', async () => {
      const cache = new MemoryCache<string>(2);
      await cache.set('a', '1');
      await cache.set('b', '2');
      await cache.set('c', '3');

      expect(await cache.get('a')).toBeNull();
      expect(await cache.get('b')).toBe('2');
      expect(await cache.get('c')).toBe('3');
    });

    it('uses a default bound of 1000 entries', async () => {
      const cache = new MemoryCache<string>();
      for (let i = 0; i < 1001; i += 1) {
        await cache.set(`key-${i}`, String(i));
      }

      // The first inserted entry was evicted; the newest survives.
      expect(await cache.get('key-0')).toBeNull();
      expect(await cache.get('key-1')).toBe('1');
      expect(await cache.get('key-1000')).toBe('1000');
    });

    it('refreshes LRU order on updates', async () => {
      const cache = new MemoryCache<string>(2);
      await cache.set('a', '1');
      await cache.set('b', '2');
      await cache.set('a', 'updated');
      await cache.set('c', '3');

      expect(await cache.get('a')).toBe('updated');
      expect(await cache.get('b')).toBeNull();
      expect(await cache.get('c')).toBe('3');
    });
  });

  describe('TTL expiry', () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it('returns the value before the TTL elapses', async () => {
      const cache = new MemoryCache<string>();
      await cache.set('key', 'value', 30);

      expect(await cache.get('key')).toBe('value');
    });

    it('returns null and evicts the entry after the TTL elapses', async () => {
      const cache = new MemoryCache<string>();
      await cache.set('key', 'value', 30);

      vi.advanceTimersByTime(30_001);

      expect(await cache.get('key')).toBeNull();
    });
  });

  describe('prefix invalidation', () => {
    it('deletes only keys matching the prefix', async () => {
      const cache = new MemoryCache<string>();
      await cache.set('user:t1', 'u1');
      await cache.set('user:t2', 'u2');
      await cache.set('session:t1', 's1');
      await cache.set('license:t1', 'l1');

      await cache.invalidatePrefix('user:');

      expect(await cache.get('user:t1')).toBeNull();
      expect(await cache.get('user:t2')).toBeNull();
      expect(await cache.get('session:t1')).toBe('s1');
      expect(await cache.get('license:t1')).toBe('l1');
    });

    it('does not evict entries for an unrelated prefix', async () => {
      const cache = new MemoryCache<string>();
      await cache.set('session:active:t1', 'a');
      await cache.set('session:recent:t1:5', 'r');

      await cache.invalidatePrefix('license:');

      expect(await cache.get('session:active:t1')).toBe('a');
      expect(await cache.get('session:recent:t1:5')).toBe('r');
    });
  });
});

describe('MemoryCache — deterministic fuzz', () => {
  const seeds = [404, 505, 606];
  const operations = 100;
  const maxEntries = 5;
  const prefixes = ['user:', 'session:', 'license:'];
  const keys = prefixes.flatMap((prefix) =>
    [0, 1, 2].map((suffix) => `${prefix}${suffix}`),
  );

  interface ModelEntry {
    value: string;
    expires: number | null;
  }

  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it.each(seeds)('seed %i preserves LRU, TTL, and exact prefix invariants', async (seed) => {
    faker.seed(seed);
    const cache = new MemoryCache<string>(maxEntries);
    const model = new Map<string, ModelEntry>();
    let lru: string[] = [];

    const remove = (key: string) => {
      model.delete(key);
      lru = lru.filter((candidate) => candidate !== key);
    };
    const touch = (key: string) => {
      const entry = model.get(key);
      lru = lru.filter((candidate) => candidate !== key);
      lru.push(key);
      if (entry !== undefined) model.set(key, entry);
    };
    const evict = () => {
      while (lru.length > maxEntries) remove(lru[0]!);
    };
    const assertMatchesModel = async () => {
      for (const key of [...model.keys()]) {
        const entry = model.get(key);
        if (!entry) continue;
        if (entry.expires !== null && Date.now() > entry.expires) {
          expect(await cache.get(key)).toBeNull();
          remove(key);
        } else {
          expect(await cache.get(key)).toBe(entry.value);
          touch(key);
        }
      }
      expect(lru.length).toBeLessThanOrEqual(maxEntries);
    };

    for (let operation = 0; operation < operations; operation += 1) {
      const choice = faker.number.int({ min: 0, max: 4 });
      const key = faker.helpers.arrayElement(keys);

      if (choice === 0) {
        const value = faker.string.alphanumeric({ length: 8 });
        const ttlSeconds = faker.number.int({ min: 1, max: 3 });
        await cache.set(key, value, ttlSeconds);
        model.set(key, {
          value,
          expires: Date.now() + ttlSeconds * 1000,
        });
        touch(key);
        evict();
      } else if (choice === 1) {
        const entry = model.get(key);
        const actual = await cache.get(key);
        if (!entry || (entry.expires !== null && Date.now() > entry.expires)) {
          expect(actual).toBeNull();
          remove(key);
        } else {
          expect(actual).toBe(entry.value);
          touch(key);
        }
      } else if (choice === 2) {
        await cache.del(key);
        remove(key);
      } else if (choice === 3) {
        vi.advanceTimersByTime(faker.number.int({ min: 0, max: 3500 }));
      } else {
        const prefix = faker.helpers.arrayElement(prefixes);
        await cache.invalidatePrefix(prefix);
        for (const candidate of keys) {
          if (candidate.startsWith(prefix)) remove(candidate);
        }
      }

      await assertMatchesModel();
    }
  });
});
