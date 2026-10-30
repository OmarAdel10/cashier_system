import { describe, expect, it } from 'vitest';

import type { AssetFetcher } from '../ports/asset-fetcher';
import { CachePolicyServiceImpl } from '../../domain/services/cache-policy-service.impl';
import { HeaderPolicyServiceImpl } from '../../domain/services/header-policy-service.impl';
import { StaticAssetClassifierImpl } from '../../domain/services/static-asset-classifier.impl';
import { ServeRequestUseCase } from '../use-cases/serve-request-use-case';

// Fuzz invariants use hand-rolled mirrors of the hardened policy — never
// the impls' own exports (anti-tautology), same discipline as the domain
// fuzz.

// Deterministic xorshift32, normalized to [0, 1). Seed 0 is a fixed
// point of xorshift32 and is rejected loudly.
function makeRng(seed: number): () => number {
  if (seed === 0) {
    throw new Error('makeRng: seed 0 is the xorshift32 fixed point');
  }
  let state = seed >>> 0;
  return () => {
    state ^= state << 13;
    state >>>= 0;
    state ^= state >>> 17;
    state ^= state << 5;
    state >>>= 0;
    return state / 0x100000000;
  };
}

const ALPHA =
  'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/-._%Å';
const IMMUTABLE_EXTS = [
  '.wasm',
  '.js',
  '.mjs',
  '.css',
  '.woff2',
  '.ttf',
] as const;

// Independent mirror of the hardened classification rule:
// last-segment + extension allowlist, no dotfiles, no traversal.
const isStaticAsset = (pathname: string): boolean => {
  let decoded: string;
  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    return false;
  }
  const segments = decoded.split('/');
  if (segments.includes('..')) return false;
  if (segments.some((s) => s.startsWith('.') && s.length > 1)) return false;
  const last = segments[segments.length - 1];
  if (!last || !last.includes('.')) return false;
  const ext = last.slice(last.lastIndexOf('.')).toLowerCase();
  return (IMMUTABLE_EXTS as readonly string[]).includes(ext) ||
    ['.html', '.htm', '.json', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico',
     '.pdf', '.txt', '.xml', '.map'].includes(ext);
};

// Independent mirror of the legacy extension extraction (undecoded).
const lastDotSuffix = (pathname: string): string => {
  const index = pathname.lastIndexOf('.');
  return index === -1 ? '' : pathname.slice(index).toLowerCase();
};

const IMMUTABLE_SET = new Set<string>(IMMUTABLE_EXTS);
const HOURLY = 'public, max-age=3600';
const IMMUTABLE = 'public, max-age=31536000, immutable';
const SPA_SHELL = 'max-age=0, must-revalidate';
const ERROR_CACHE = 'max-age=0, must-revalidate';

// Fingerprinted asset: hex hash (8+ chars) before extension
const FINGERPRINT_HASH = /[0-9a-f]{8,}\.[a-z0-9]+$/i;

// Response construction in undici rejects a body on null-body status
// 304 — the only member of our status pool with that constraint.
const NULL_BODY_STATUSES = new Set([304]);

const METHODS = ['GET', 'GET', 'GET', 'POST', 'HEAD', 'PUT'] as const;
const STATUSES = [
  200, 200, 200, 200, 200, 301, 304, 399, 400, 404, 500,
] as const;

const UPSTREAM_OK_HEADERS: Record<string, string> = {
  'Content-Type': 'application/javascript',
  ETag: '"etag-demo"',
  'X-Frame-Options': 'SAMEORIGIN',
  'Cache-Control': 'no-store',
};

const UPSTREAM_ERROR_HEADERS: Record<string, string> = {
  'Content-Type': 'text/plain',
};

function headerSnapshot(headers: Headers): Record<string, string> {
  const snapshot: Record<string, string> = {};
  headers.forEach((value, name) => {
    snapshot[name] = value;
  });
  return snapshot;
}

describe('ServeRequestUseCase fuzz (deterministic routing + decoration)', () => {
  const seeds = [7101, 7202, 7303] as const;
  const operations = 200;

  it.each(seeds)('seed %i: invariants hold over 200 random commands', async (seed) => {
    const rng = makeRng(seed);
    const alphabet = ALPHA.split('');

    const pick = <T>(items: readonly T[]): T => {
      const item = items[Math.floor(rng() * items.length)];
      if (item === undefined) {
        throw new Error('fuzz: undefined pick — pool exhausted');
      }
      return item;
    };

    const randomPathname = (): string => {
      const length = 1 + Math.floor(rng() * 12);
      let base = '';
      for (let i = 0; i < length; i += 1) {
        base += pick(alphabet);
      }
      if (rng() < 0.2) {
        base = `/assets/${base}`;
      } else if (!base.startsWith('/')) {
        base = `/${base}`;
      }
      // Some paths get a pooled immutable extension, some get a
      // fingerprinted extension (hash before ext), some stay plain.
      const r = rng();
      if (r < 0.33) {
        const ext = pick(IMMUTABLE_EXTS);
        base += rng() < 0.5 ? ext : ext.toUpperCase();
      } else if (r < 0.66) {
        const hash = Array.from({ length: 8 }, () =>
          '0123456789abcdef'[Math.floor(rng() * 16)],
        ).join('');
        const dot = base.lastIndexOf('.');
        if (dot === -1) base += `.${hash}.wasm`;
        else base = `${base.slice(0, dot)}.${hash}${base.slice(dot)}`;
      }
      return base;
    };

    let fallbackHits = 0;
    let assetHits = 0;
    let decoratedErrorHits = 0;
    let nonGetHits = 0;
    let rootHits = 0;

    for (let op = 0; op < operations; op += 1) {
      // Op 0 is the guaranteed GET '/' command — the root arm of the
      // fallback rule takes the shell branch deterministically.
      const method = op === 0 ? 'GET' : pick(METHODS);
      const pathname = op === 0 ? '/' : randomPathname();
      const status = pick(STATUSES);
      const body = NULL_BODY_STATUSES.has(status) ? null : 'OK';
      const expectedBody = body ?? '';

      const calls: string[] = [];
      const fetcher: AssetFetcher = {
        fetchShell: async () => {
          calls.push('shell');
          return new Response(body, {
            status,
            headers: UPSTREAM_OK_HEADERS,
          });
        },
        forwardOriginal: async () => {
          calls.push('original');
          return new Response(body, {
            status,
            headers: UPSTREAM_OK_HEADERS,
          });
        },
      };
      const useCase = new ServeRequestUseCase({
        fetcher,
        cachePolicy: new CachePolicyServiceImpl(new StaticAssetClassifierImpl()),
        headerPolicy: new HeaderPolicyServiceImpl(),
        classifier: new StaticAssetClassifierImpl(),
      });

      const res = await useCase.execute({ method, pathname });

      // Hardened classification: last-segment + allowlist, no dotfiles,
      // no traversal.
      const isStatic = isStaticAsset(pathname);
      const fallback = method === 'GET' && (pathname === '/' || !isStatic);

      // Invariant 1 (routing): fallback takes shell, asset takes original.
      expect(calls).toEqual([fallback ? 'shell' : 'original']);
      if (fallback) {
        fallbackHits += 1;
        if (pathname === '/') rootHits += 1;
      } else if (method !== 'GET') nonGetHits += 1;

      if (fallback) {
        // Invariant 2 (fallback decoration): shell always gets SPA_SHELL
        // cache + security headers, regardless of upstream status.
        expect(res.status).toBe(status);
        expect(await res.text()).toBe(expectedBody);
        expect(res.headers.get('Cache-Control')).toBe(SPA_SHELL);
        expect(res.headers.get('X-Frame-Options')).toBe('DENY');
      } else if (status >= 400) {
        // Invariant 3 (DAFTARI-147): asset errors are decorated, not
        // passed through untouched. Error cache has no 'public'.
        decoratedErrorHits += 1;
        expect(res.status).toBe(status);
        expect(await res.text()).toBe(expectedBody);
        expect(res.headers.get('X-Frame-Options')).toBe('DENY');
        expect(res.headers.get('Cache-Control')).toBe(ERROR_CACHE);
        expect(res.headers.get('Cache-Control')).not.toContain('public');
      } else {
        // Invariant 4 (asset decoration): fingerprint-based immutable
        // cache; hostile upstream values overridden.
        assetHits += 1;
        expect(res.status).toBe(status);
        expect(await res.text()).toBe(expectedBody);
        const ext = lastDotSuffix(pathname);
        const isFingerprinted = FINGERPRINT_HASH.test(pathname);
        const expectedCache =
          isFingerprinted && IMMUTABLE_SET.has(ext) ? IMMUTABLE : HOURLY;
        expect(res.headers.get('Cache-Control')).toBe(expectedCache);
        expect(res.headers.get('X-Frame-Options')).toBe('DENY');
      }
    }

    // Reachability guards: every branch must be genuinely exercised
    // under each seed.
    expect(fallbackHits).toBeGreaterThan(0);
    expect(assetHits).toBeGreaterThan(0);
    expect(decoratedErrorHits).toBeGreaterThan(0);
    expect(nonGetHits).toBeGreaterThan(0);
    expect(rootHits).toBeGreaterThan(0);
  });

  it('makeRng rejects seed 0 (xorshift32 fixed point)', () => {
    expect(() => makeRng(0)).toThrow('makeRng: seed 0 is the xorshift32 fixed point');
  });
});
