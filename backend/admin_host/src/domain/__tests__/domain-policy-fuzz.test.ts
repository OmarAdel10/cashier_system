/**
 * Deterministic fuzz tests for the admin_host domain policies.
 *
 * Uses a seeded xorshift32 PRNG so every run is reproducible (no faker).
 * Random pathnames exercise cache policy, header policy, and asset
 * classification together, checking cross-service invariants instead of
 * re-stating implementation details.
 */
import { describe, expect, it } from 'vitest';
import { CachePolicyServiceImpl } from '../services/cache-policy-service.impl';
import { HeaderPolicyServiceImpl } from '../services/header-policy-service.impl';
import { StaticAssetClassifierImpl } from '../services/static-asset-classifier.impl';

function makeRng(seed: number) {
  let state = seed >>> 0;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return (state >>> 0) / 0xffffffff;
  };
}

const seeds = [7101, 7202, 7303];
const operations = 200;
const alpha = 'abcdefghijklmnopqrstuvwxyz0123456789/.-';
const IMMUTABLE_EXTS = new Set(['.wasm', '.js', '.mjs', '.css', '.woff2', '.ttf']);
const IMMUTABLE = 'public, max-age=31536000, immutable';
const HOURLY = 'public, max-age=3600';

function randomPathname(rng: () => number): string {
  const length = Math.floor(rng() * 30) + 1;
  return Array.from({ length }, () => alpha[Math.floor(rng() * alpha.length)]).join('');
}

describe('admin_host domain policies — deterministic fuzz', () => {
  it.each(seeds)(
    'seed %i keeps all three policies consistent over %i random pathnames',
    (seed) => {
      const rng = makeRng(seed);
      const cache = new CachePolicyServiceImpl();
      const headers = new HeaderPolicyServiceImpl();
      const classifier = new StaticAssetClassifierImpl();

      for (let op = 0; op < operations; op += 1) {
        const pathname =
          rng() < 0.2 ? `/assets/${randomPathname(rng)}` : `/${randomPathname(rng)}`;
        const ext = classifier.extOf(pathname);

        // Invariant 1: cache policy always picks one of the two directives.
        const cacheControl = cache.cacheControlFor(pathname);
        expect(cacheControl === IMMUTABLE || cacheControl === HOURLY).toBe(true);

        // Invariant 2: immutable cache iff the extension is in the set.
        expect(cacheControl === IMMUTABLE).toBe(IMMUTABLE_EXTS.has(ext));

        // Invariant 3: classification matches the SPA-fallback rule.
        expect(classifier.isStaticAssetPath(pathname)).toBe(
          pathname.includes('.') || pathname.startsWith('/assets/'),
        );

        // Invariant 4: extension is empty or a lowercase dot-suffix.
        expect(ext === '' || (ext.startsWith('.') && ext === ext.toLowerCase())).toBe(
          true,
        );

        // Invariant 5: header policy is constant and complete.
        const security = headers.securityHeaders();
        expect(security['Cross-Origin-Opener-Policy']).toBe('same-origin-allow-popups');
        expect(security['X-Frame-Options']).toBe('DENY');
      }
    },
  );
});
