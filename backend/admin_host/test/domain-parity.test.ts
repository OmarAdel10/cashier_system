import { describe, expect, it } from 'vitest';

import worker from '../src/index';
import type { AssetBindings } from '../src/index';
import { CachePolicyServiceImpl } from '../src/domain/services/cache-policy-service.impl';
import { HeaderPolicyServiceImpl } from '../src/domain/services/header-policy-service.impl';
import { StaticAssetClassifierImpl } from '../src/domain/services/static-asset-classifier.impl';

/**
 * Parity canary: while src/index.ts still holds its own copy of the
 * policy constants (until the wiring step), pin the legacy handler's
 * observable decisions to the extracted domain services. If either
 * side drifts on its own, this test fails.
 *
 * Pinned here:
 * - static-vs-SPA classification over a shared corpus
 * - routing: SPA rows are rewritten to /index.html, asset rows pass
 *   through to the assets binding unchanged
 * - final header composition on decorated responses: a copy of the
 *   upstream headers + the domain security headers + Cache-Control
 *   from the domain cache policy (immutable set end-to-end)
 * - status and statusText survive decoration
 * - asset responses with status >= 400 are returned untouched
 * - SPA-fallback responses carry the full header set regardless of
 *   upstream status
 * - non-GET requests bypass the fallback (asset branch)
 *
 * Delete or rewrite at the wiring step, when index.ts starts consuming
 * these services directly — carry the routing, >=400-passthrough, and
 * method-gating pins into the wiring tests, and keep exactly one
 * canonical security-header oracle after this file goes away.
 */

const UPSTREAM_OK_HEADERS: Record<string, string> = {
  'Content-Type': 'application/javascript',
  ETag: '"etag-demo"',
};

const UPSTREAM_ERROR_HEADERS: Record<string, string> = {
  'Content-Type': 'text/plain',
};

function makeEnv(upstream: () => Response): {
  env: AssetBindings;
  requestedPaths: string[];
} {
  const requestedPaths: string[] = [];
  const env: AssetBindings = {
    ASSETS: {
      fetch: async (request: Request) => {
        requestedPaths.push(new URL(request.url).pathname);
        return upstream();
      },
    },
    ENVIRONMENT: 'test',
  };
  return { env, requestedPaths };
}

function headerSnapshot(headers: Headers): Record<string, string> {
  const snapshot: Record<string, string> = {};
  headers.forEach((value, name) => {
    snapshot[name] = value;
  });
  return snapshot;
}

function decoratedSnapshot(
  pathname: string,
  headerPolicy: HeaderPolicyServiceImpl,
  cache: CachePolicyServiceImpl,
): Record<string, string> {
  const expected = new Headers(UPSTREAM_OK_HEADERS);
  for (const [name, value] of Object.entries(headerPolicy.securityHeaders())) {
    expected.set(name, value);
  }
  expected.set('Cache-Control', cache.cacheControlFor(pathname));
  return headerSnapshot(expected);
}

describe('domain parity canary (legacy handler vs domain services)', () => {
  const cache = new CachePolicyServiceImpl();
  const headerPolicy = new HeaderPolicyServiceImpl();
  const classifier = new StaticAssetClassifierImpl();

  const corpus: Array<[pathname: string, spaFallback: boolean, immutable: boolean]> = [
    ['/main.wasm', false, true],
    ['/assets/app.js', false, true],
    ['/flutter_bootstrap.js', false, true],
    ['/manifest.json', false, false],
    ['/x.mjs', false, true],
    ['/x.css', false, true],
    ['/x.woff2', false, true],
    ['/x.ttf', false, true],
    ['/a.b/main', false, false],
    ['/assets/no-extension', false, false],
    ['/', true, false],
    ['/settings', true, false],
    ['/users/42/profile', true, false],
  ];

  it('classifies static-vs-SPA exactly like the classifier service', () => {
    for (const [pathname, spaFallback] of corpus) {
      expect(classifier.isStaticAssetPath(pathname)).toBe(!spaFallback);
    }
  });

  it('routes SPA rows to /index.html and passes asset rows through unchanged', async () => {
    for (const [pathname, spaFallback] of corpus) {
      const { env, requestedPaths } = makeEnv(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      await worker.fetch(new Request(`https://admin.example${pathname}`), env);
      expect(requestedPaths).toEqual([spaFallback ? '/index.html' : pathname]);
    }
  });

  it('serves every corpus path with the domain cache policy and full header set', async () => {
    for (const [pathname, , immutable] of corpus) {
      const { env } = makeEnv(
        () =>
          new Response('OK', {
            status: 200,
            statusText: 'Upstream OK',
            headers: UPSTREAM_OK_HEADERS,
          }),
      );
      const res = await worker.fetch(
        new Request(`https://admin.example${pathname}`),
        env,
      );
      expect(res.status).toBe(200);
      expect(res.statusText).toBe('Upstream OK');
      expect(headerSnapshot(res.headers)).toEqual(
        decoratedSnapshot(pathname, headerPolicy, cache),
      );
      if (immutable) {
        expect(res.headers.get('Cache-Control')).toBe(
          'public, max-age=31536000, immutable',
        );
      }
    }
  });

  it('returns asset responses with status >= 400 untouched', async () => {
    const errorRows: Array<[status: number, pathname: string]> = [
      [400, '/x.css'],
      [404, '/main.wasm'],
      [500, '/assets/app.js'],
    ];
    for (const [status, pathname] of errorRows) {
      const { env, requestedPaths } = makeEnv(
        () =>
          new Response('missing', {
            status,
            statusText: 'Upstream error',
            headers: UPSTREAM_ERROR_HEADERS,
          }),
      );
      const res = await worker.fetch(
        new Request(`https://admin.example${pathname}`),
        env,
      );
      expect(requestedPaths).toEqual([pathname]);
      expect(res.status).toBe(status);
      expect(res.statusText).toBe('Upstream error');
      expect(headerSnapshot(res.headers)).toEqual(
        headerSnapshot(new Headers(UPSTREAM_ERROR_HEADERS)),
      );
    }
  });

  it('decorates SPA fallback responses with the full header set regardless of status', async () => {
    for (const status of [200, 404]) {
      const { env, requestedPaths } = makeEnv(
        () => new Response('shell', { status, headers: UPSTREAM_OK_HEADERS }),
      );
      const res = await worker.fetch(
        new Request('https://admin.example/settings'),
        env,
      );
      expect(requestedPaths).toEqual(['/index.html']);
      expect(res.status).toBe(status);
      expect(headerSnapshot(res.headers)).toEqual(
        decoratedSnapshot('/index.html', headerPolicy, cache),
      );
    }
  });

  it('bypasses the SPA fallback for non-GET methods (asset branch)', async () => {
    const { env, requestedPaths } = makeEnv(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const res = await worker.fetch(
      new Request('https://admin.example/settings', { method: 'POST' }),
      env,
    );
    expect(requestedPaths).toEqual(['/settings']);
    expect(res.status).toBe(200);
    expect(headerSnapshot(res.headers)).toEqual(
      decoratedSnapshot('/settings', headerPolicy, cache),
    );
  });
});
