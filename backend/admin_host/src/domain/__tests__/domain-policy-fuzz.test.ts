/**
 * Deterministic fuzz tests for the admin_host domain policies.
 *
 * Uses a seeded xorshift32 PRNG so every run is reproducible (no faker).
 * Random pathnames exercise cache policy, header policy, and asset
 * classification together. The expected values below are deliberate
 * verbatim copies of the legacy handler's policy — they act as change
 * detectors. Never import implementation constants here: that would make
 * the oracles tautological.
 */
import { describe, expect, it } from 'vitest';
import { CachePolicyServiceImpl } from '../services/cache-policy-service.impl';
import { HeaderPolicyServiceImpl } from '../services/header-policy-service.impl';
import { StaticAssetClassifierImpl } from '../services/static-asset-classifier.impl';

function makeRng(seed: number) {
  if (seed === 0) {
    // 0 is xorshift32's fixed point: the run would silently degenerate
    // to a constant sequence instead of fuzzing anything.
    throw new Error('xorshift32 seed must be nonzero (0 is a fixed point)');
  }
  let state = seed >>> 0;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return (state >>> 0) / 0x100000000;
  };
}

const seeds = [7101, 7202, 7303];
const operations = 200;
const alpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/.-';
const IMMUTABLE_EXTS = ['.wasm', '.js', '.mjs', '.css', '.woff2', '.ttf'];
const IMMUTABLE_EXT_SET = new Set(IMMUTABLE_EXTS);
const IMMUTABLE = 'public, max-age=31536000, immutable';
const HOURLY = 'public, max-age=3600';

const EXPECTED_HEADERS: Record<string, string> = {
  'Cross-Origin-Embedder-Policy': 'require-corp',
  'Cross-Origin-Opener-Policy': 'same-origin-allow-popups',
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  'Strict-Transport-Security': 'max-age=63072000; includeSubDomains; preload',
  'Content-Security-Policy':
    "default-src 'self'; object-src 'none'; base-uri 'self'; " +
    "script-src 'self' 'wasm-unsafe-eval' https://apis.google.com; " +
    "style-src 'self' 'unsafe-inline'; " +
    "font-src 'self' data:; img-src 'self' data:; " +
    "connect-src 'self' https://*.daftariapp.workers.dev wss://*.daftariapp.workers.dev " +
    'https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com; ' +
    "frame-src 'self' https://*.firebaseapp.com; " +
    "frame-ancestors 'none'",
};

function randomPathname(rng: () => number): string {
  const length = Math.floor(rng() * 30) + 1;
  return Array.from({ length }, () => alpha[Math.floor(rng() * alpha.length)]).join('');
}

function pickPooledExt(rng: () => number): string {
  const pick = IMMUTABLE_EXTS[Math.floor(rng() * IMMUTABLE_EXTS.length)];
  if (pick === undefined) throw new Error('pooled extension pick failed');
  return rng() < 0.5 ? pick : pick.toUpperCase();
}

describe('admin_host domain policies — deterministic fuzz', () => {
  it.each(seeds)(
    `seed %s keeps all three policies consistent over ${operations} random pathnames`,
    (seed) => {
      const rng = makeRng(seed);
      const cache = new CachePolicyServiceImpl();
      const headers = new HeaderPolicyServiceImpl();
      const classifier = new StaticAssetClassifierImpl();

      const initialHeaders = headers.securityHeaders();
      let immutableHits = 0;

      for (let op = 0; op < operations; op += 1) {
        const base =
          rng() < 0.2 ? `/assets/${randomPathname(rng)}` : `/${randomPathname(rng)}`;
        // A quarter of the paths get a pooled immutable extension appended,
        // so the immutable branch of the cache policy is actually exercised —
        // plain random pathnames over this alphabet almost never hit it.
        // Half the appended extensions are uppercased, so the lowercasing
        // normalization is exercised under fuzz too.
        const appended = rng() < 0.25 ? pickPooledExt(rng) : null;
        const pathname = appended === null ? base : `${base}${appended}`;
        const ext = classifier.extOf(pathname);

        if (appended !== null) {
          // The appended extension must survive extOf as itself (lowercased).
          expect(ext).toBe(appended.toLowerCase());
        }

        // Invariant 1: cache policy always picks one of the two directives.
        const cacheControl = cache.cacheControlFor(pathname);
        expect(cacheControl === IMMUTABLE || cacheControl === HOURLY).toBe(true);
        if (cacheControl === IMMUTABLE) immutableHits += 1;

        // Invariant 2: immutable cache iff the extension is in the set.
        expect(cacheControl === IMMUTABLE).toBe(IMMUTABLE_EXT_SET.has(ext));

        // Invariant 3: classification matches the SPA-fallback rule
        // (deliberate verbatim copy of the legacy expression).
        expect(classifier.isStaticAssetPath(pathname)).toBe(
          pathname.includes('.') || pathname.startsWith('/assets/'),
        );

        // Invariant 4: extension is empty or a lowercase dot-suffix.
        expect(ext === '' || (ext.startsWith('.') && ext === ext.toLowerCase())).toBe(
          true,
        );
      }

      // Invariant 5: the security-header map is constant across the whole
      // run and matches the legacy policy exactly.
      expect(initialHeaders).toEqual(EXPECTED_HEADERS);
      expect(headers.securityHeaders()).toEqual(EXPECTED_HEADERS);

      // The pooled extensions must actually reach the immutable branch.
      expect(immutableHits).toBeGreaterThan(0);
    },
  );
});
