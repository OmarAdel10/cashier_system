import { describe, expect, it } from 'vitest';

import type { AssetFetcher } from '../ports/asset-fetcher';
import { CachePolicyServiceImpl } from '../../domain/services/cache-policy-service.impl';
import { HeaderPolicyServiceImpl } from '../../domain/services/header-policy-service.impl';
import { StaticAssetClassifierImpl } from '../../domain/services/static-asset-classifier.impl';
import { ServeRequestUseCase } from '../use-cases/serve-request-use-case';

// Fuzz invariants use hand-rolled mirrors of the preserved legacy
// expressions — never the impls' own exports (anti-tautology), same
// discipline as the domain fuzz.

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
  'abcdefghijklmnopqrstuvwxyz0123456789/-._%Å';
const IMMUTABLE_EXTS = [
  '.wasm',
  '.js',
  '.mjs',
  '.css',
  '.woff2',
  '.ttf',
] as const;

// Independent mirror of the legacy classification rule.
const isSpaRoute = (method: string, pathname: string): boolean =>
  method === 'GET' &&
  (pathname === '/' ||
    !(pathname.includes('.') || pathname.startsWith('/assets/')));

// Independent mirror of the legacy extension extraction.
const lastDotSuffix = (pathname: string): string => {
  const index = pathname.lastIndexOf('.');
  return index === -1 ? '' : pathname.slice(index).toLowerCase();
};

const IMMUTABLE_SET = new Set<string>(IMMUTABLE_EXTS);
const HOURLY = 'public, max-age=3600';
const IMMUTABLE = 'public, max-age=31536000, immutable';

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
      // A quarter of the paths get a pooled immutable extension
      // appended (half uppercased) so the immutable branch and the
      // case normalization are both exercised under fuzz.
      if (rng() < 0.25) {
        const ext = pick(IMMUTABLE_EXTS);
        base += rng() < 0.5 ? ext : ext.toUpperCase();
      }
      return base;
    };

    let fallbackHits = 0;
    let assetHits = 0;
    let passthroughHits = 0;
    let nonGetHits = 0;
    let rootHits = 0;

    for (let op = 0; op < operations; op += 1) {
      const method = pick(METHODS);
      // Op 0 is the guaranteed '/' command — the root arm of the
      // fallback rule is exercised deterministically, never left to
      // the generator (round-4 guard).
      const pathname = op === 0 ? '/' : randomPathname();
      if (pathname === '/') rootHits += 1;
      const status = pick(STATUSES);
      const body = NULL_BODY_STATUSES.has(status) ? null : 'OK';
      const expectedBody = body ?? '';

      const calls: string[] = [];
      // Split-port mock: the branch taken is the observable —
      // 'shell' (fetchShell) or 'original' (forwardOriginal). No
      // pathname crosses the fetch seam.
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
        cachePolicy: new CachePolicyServiceImpl(),
        headerPolicy: new HeaderPolicyServiceImpl(),
        classifier: new StaticAssetClassifierImpl(),
      });

      const res = await useCase.execute({ method, pathname });

      const fallback = isSpaRoute(method, pathname);

      // Invariant 1 (routing): the fallback branch takes the shell
      // fetch, the asset branch forwards the original request.
      expect(calls).toEqual([fallback ? 'shell' : 'original']);
      if (fallback) fallbackHits += 1;
      else if (method !== 'GET') nonGetHits += 1;

      if (fallback) {
        // Invariant 2 (fallback decoration): regardless of upstream
        // status, the shell response is decorated with hourly cache.
        expect(res.status).toBe(status);
        expect(await res.text()).toBe(expectedBody);
        expect(res.headers.get('Cache-Control')).toBe(HOURLY);
        expect(res.headers.get('X-Frame-Options')).toBe('DENY');
      } else if (status >= 400) {
        // Invariant 3 (passthrough): asset errors ship untouched —
        // status, body, and headers all upstream.
        passthroughHits += 1;
        expect(res.status).toBe(status);
        expect(await res.text()).toBe(expectedBody);
        expect(headerSnapshot(res.headers)).toEqual(
          headerSnapshot(new Headers(UPSTREAM_OK_HEADERS)),
        );
        expect(res.headers.get('Cache-Control')).toBe('no-store');
      } else {
        // Invariant 4 (asset decoration): cache policy applied per
        // extension; hostile upstream values overridden.
        assetHits += 1;
        expect(res.status).toBe(status);
        expect(await res.text()).toBe(expectedBody);
        const ext = lastDotSuffix(pathname);
        const expectedCache = IMMUTABLE_SET.has(ext) ? IMMUTABLE : HOURLY;
        expect(res.headers.get('Cache-Control')).toBe(expectedCache);
        expect(res.headers.get('X-Frame-Options')).toBe('DENY');
      }
    }

    // Reachability guards: every branch must be genuinely exercised
    // under each seed — a degenerate generator must fail loudly.
    expect(fallbackHits).toBeGreaterThan(0);
    expect(assetHits).toBeGreaterThan(0);
    expect(passthroughHits).toBeGreaterThan(0);
    expect(nonGetHits).toBeGreaterThan(0);
    expect(rootHits).toBeGreaterThan(0);
  });
});
