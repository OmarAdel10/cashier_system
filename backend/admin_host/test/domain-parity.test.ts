import { describe, expect, it, vi } from 'vitest';

vi.mock('@libsql/client', () => ({
  createClient: () => ({ execute: async () => ({ rows: [], columns: [], rowsAffected: 0 }) }),
}));

import worker from '../src/index';
import type { AssetBindings } from '../src/index';
import { CachePolicyServiceImpl } from '../src/domain/services/cache-policy-service.impl';
import { HeaderPolicyServiceImpl } from '../src/domain/services/header-policy-service.impl';
import { StaticAssetClassifierImpl } from '../src/domain/services/static-asset-classifier.impl';

/**
 * Parity canary: while src/index.ts still holds its own copy of the
 * policy constants (until the wiring step), pin the legacy handler's
 * observable decisions to the extracted domain services. If either
 * side drifts on its own, this test fails. Delete or rewrite at the
 * wiring step, when index.ts starts consuming these services directly.
 */

const UPSTREAM_HEADERS: Record<string, string> = {
  'Content-Type': 'application/javascript',
  'ETag': '"etag-demo"',
};

const assetResponse = vi.fn(async () =>
  new Response('OK', { status: 200, headers: UPSTREAM_HEADERS }),
);

const env: AssetBindings = {
  ASSETS: { fetch: async (_req: Request) => assetResponse() },
  ENVIRONMENT: 'test',
};

function headerSnapshot(h: Headers): Record<string, string> {
  const out: Record<string, string> = {};
  h.forEach((v, k) => {
    out[k] = v;
  });
  return out;
}

describe('domain parity canary (legacy handler vs domain services)', () => {
  const cache = new CachePolicyServiceImpl();
  const headers = new HeaderPolicyServiceImpl();
  const classifier = new StaticAssetClassifierImpl();

  const corpus: Array<[pathname: string, spaFallback: boolean]> = [
    ['/main.wasm', false],
    ['/assets/app.js', false],
    ['/flutter_bootstrap.js', false],
    ['/manifest.json', false],
    ['/settings', true],
    ['/users/42/profile', true],
  ];

  it('classifies static-vs-SPA exactly like the classifier service', () => {
    for (const [pathname, spaFallback] of corpus) {
      expect(classifier.isStaticAssetPath(pathname)).toBe(!spaFallback);
    }
  });

  it('serves every corpus path with the domain cache policy and full header set', async () => {
    for (const [pathname] of corpus) {
      const res = await worker.fetch(
        new Request(`https://admin.example${pathname}`),
        env,
      );
      expect(res.status).toBe(200);

      // Final headers = upstream copy + domain security headers +
      // Cache-Control from the domain cache policy — nothing more.
      const expected = new Headers(UPSTREAM_HEADERS);
      for (const [name, value] of Object.entries(headers.securityHeaders())) {
        expected.set(name, value);
      }
      expected.set('Cache-Control', cache.cacheControlFor(pathname));

      expect(headerSnapshot(res.headers)).toEqual(headerSnapshot(expected));
    }
  });
});
