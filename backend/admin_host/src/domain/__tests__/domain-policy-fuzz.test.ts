/**
 * Deterministic fuzz tests for the admin_host domain policies.
 *
 * Uses a seeded xorshift32 PRNG so every run is reproducible (no faker).
 * Random pathnames exercise cache policy, header policy, and asset
 * classification together. The expected values below are deliberate
 * copies of the hardened policy — they act as change detectors.
 * Never import implementation constants here: that would make the
 * oracles tautological.
 */
import { describe, expect, it } from 'vitest';
import { CachePolicyServiceImpl } from '../services/cache-policy-service.impl';
import { HeaderPolicyServiceImpl } from '../services/header-policy-service.impl';
import { StaticAssetClassifierImpl } from '../services/static-asset-classifier.impl';

function makeRng(seed: number) {
  if (seed === 0) {
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
const alpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/.-%Å';
const IMMUTABLE_EXTS = ['.wasm', '.js', '.mjs', '.css', '.woff2', '.ttf'];
const IMMUTABLE_EXT_SET = new Set(IMMUTABLE_EXTS);
const IMMUTABLE = 'public, max-age=31536000, immutable';
const HOURLY = 'public, max-age=3600';
const SPA_SHELL = 'max-age=0, must-revalidate';

// Fingerprinted asset: hex hash (8+ chars) before extension
const FINGERPRINT_HASH = /[0-9a-f]{8,}\.[a-z0-9]+$/i;

const EXPECTED_HEADERS: Record<string, string> = {
  'Cross-Origin-Embedder-Policy': 'require-corp',
  'Cross-Origin-Opener-Policy': 'same-origin-allow-popups',
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy':
    'camera=(), microphone=(), geolocation=(), payment=(), usb=(), magnetometer=(), gyroscope=()',
  'Strict-Transport-Security': 'max-age=63072000; includeSubDomains',
  'Content-Security-Policy':
    "default-src 'self'; object-src 'none'; base-uri 'self'; " +
    "script-src 'self' 'wasm-unsafe-eval' 'require-trusted-types-for' 'script' https://apis.google.com; " +
    "style-src 'self'; " +
    "font-src 'self' data:; img-src 'self' data:; " +
    "connect-src 'self' https://daftariapp.workers.dev wss://daftariapp.workers.dev " +
    'https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com; ' +
    "frame-src 'self' https://*.firebaseapp.com; " +
    "frame-ancestors 'none'; " +
    "form-action 'self'; " +
    "report-uri /csp-report",
  'Cross-Origin-Resource-Policy': 'same-origin',
};

function randomPathname(rng: () => number): string {
  const length = Math.floor(rng() * 30) + 1;
  return Array.from({ length }, () => alpha[Math.floor(rng() * alpha.length)]).join('');
}

function lastDotSuffix(pathname: string): string {
  const dot = pathname.lastIndexOf('.');
  return dot === -1 ? '' : pathname.slice(dot).toLowerCase();
}

function pickPooledExt(rng: () => number): string {
  const pick = IMMUTABLE_EXTS[Math.floor(rng() * IMMUTABLE_EXTS.length)];
  if (pick === undefined) throw new Error('pooled extension pick failed');
  return rng() < 0.5 ? pick : pick.toUpperCase();
}

function makeFingerprinted(base: string, rng: () => number): string {
  const hash = Array.from({ length: 8 }, () =>
    '0123456789abcdef'[Math.floor(rng() * 16)],
  ).join('');
  // Insert hash before the extension: main.js → main.a1b2c3d4.js
  const lastDot = base.lastIndexOf('.');
  if (lastDot === -1) return `${base}.${hash}.wasm`;
  return `${base.slice(0, lastDot)}.${hash}${base.slice(lastDot)}`;
}

describe('admin_host domain policies — deterministic fuzz', () => {
  it.each(seeds)(
    `seed %s keeps all three policies consistent over ${operations} random pathnames`,
    (seed) => {
      const rng = makeRng(seed);
      const cache = new CachePolicyServiceImpl(new StaticAssetClassifierImpl());
      const headers = new HeaderPolicyServiceImpl();
      const classifier = new StaticAssetClassifierImpl();

      const initialHeaders = headers.securityHeaders();
      let immutableHits = 0;

      for (let op = 0; op < operations; op += 1) {
        const base =
          rng() < 0.2 ? `/assets/${randomPathname(rng)}` : `/${randomPathname(rng)}`;
        // Roughly a third of paths get a pooled immutable extension, a third
        // get a fingerprinted extension (hash before ext), a third stay plain.
        const r = rng();
        let pathname: string;
        if (r < 0.33) {
          const appended = pickPooledExt(rng);
          pathname = `${base}${appended}`;
        } else if (r < 0.66) {
          pathname = makeFingerprinted(base, rng);
        } else {
          pathname = base;
        }

        // Independent mirror: extOf must equal the lowercased suffix from
        // the last dot on the decoded pathname.
        expect(classifier.extOf(pathname)).toBe(lastDotSuffix(pathname));

        // Invariant 1: cache policy always picks one of the three directives.
        const cacheControl = cache.cacheControlFor(pathname);
        expect(
          cacheControl === IMMUTABLE ||
            cacheControl === HOURLY ||
            cacheControl === SPA_SHELL,
        ).toBe(true);

        // Invariant 2: immutable cache iff fingerprinted with immutable ext.
        const ext = classifier.extOf(pathname);
        const isFingerprinted = FINGERPRINT_HASH.test(pathname);
        const isImmutableExt = IMMUTABLE_EXT_SET.has(ext);
        const isShell = pathname === '/' || pathname === '/index.html';
        expect(cacheControl === IMMUTABLE).toBe(
          isFingerprinted && isImmutableExt && !isShell,
        );
        if (cacheControl === IMMUTABLE) immutableHits += 1;

        // Invariant 3: SPA shell always gets short-lived cache.
        if (isShell) {
          expect(cacheControl).toBe(SPA_SHELL);
        }

        // Invariant 4: classification uses last-segment + extension allowlist.
        // A path classifies as static only if its last segment has a dot
        // with an allowlisted extension, no dotfile segments, no traversal.
        const isStatic = classifier.isStaticAssetPath(pathname);
        // Invalid URL encoding → classifier rejects (secure fail-closed).
        let decodable = true;
        let decoded: string;
        try {
          decoded = decodeURIComponent(pathname);
        } catch {
          decodable = false;
          decoded = pathname;
        }
        const segments = decoded.split('/');
        const hasTraversal = segments.includes('..');
        const hasDotfile = segments.some((s) => s.startsWith('.') && s.length > 1);
        const lastSegment = segments[segments.length - 1];
        let allowlistedExt = false;
        if (lastSegment) {
          const lastDot = lastSegment.lastIndexOf('.');
          if (lastDot !== -1) {
            const ext = lastSegment.slice(lastDot).toLowerCase();
            allowlistedExt =
              IMMUTABLE_EXT_SET.has(ext) ||
              [
                '.html', '.htm', '.json', '.png', '.jpg', '.jpeg', '.gif',
                '.svg', '.ico', '.pdf', '.txt', '.xml', '.map', '.mjs',
                '.woff', '.woff2', '.ttf', '.otf', '.eot', '.mp4', '.webm',
                '.mp3', '.wav', '.zip',
              ].includes(ext);
          }
        }
        const expectedStatic =
          decodable &&
          !hasTraversal &&
          !hasDotfile &&
          !!lastSegment &&
          lastSegment.includes('.') &&
          allowlistedExt;
        expect(isStatic).toBe(expectedStatic);
      }

      // Invariant 5: the security-header map is constant and matches the hardened policy.
      expect(initialHeaders).toEqual(EXPECTED_HEADERS);
      expect(headers.securityHeaders()).toEqual(EXPECTED_HEADERS);

      // Fingerprinted assets must actually reach the immutable branch.
      expect(immutableHits).toBeGreaterThan(0);
    },
  );
});
