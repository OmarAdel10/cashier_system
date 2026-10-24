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
 *   through to the assets binding with method and full URL intact
 * - final header composition on decorated responses: a copy of the
 *   upstream headers + the domain security headers + Cache-Control
 *   from the domain cache policy (immutable set end-to-end)
 * - status, statusText, and body survive decoration
 * - asset responses with status >= 400 are returned untouched
 * - sub-400 non-2xx asset responses (redirects / not-modified / 3xx,
 *   and the 399 boundary) are decorated like 2xx responses
 * - SPA-fallback responses carry the full header set regardless of
 *   upstream status
 * - non-GET requests bypass the fallback (asset branch)
 * - the query string is stripped by the SPA-fallback rewrite but
 *   forwarded on the asset branch
 * - request headers (Accept) survive both the fallback rewrite and
 *   the asset passthrough
 *
 * Delete or rewrite at the wiring step, when index.ts starts consuming
 * these services directly — carry the routing, >=400-passthrough,
 * sub-400 non-2xx (3xx) decoration, any-status fallback decoration,
 * and method-gating pins into the wiring tests, and keep exactly one
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
  requestedRequests: string[];
  requestedAccepts: string[];
} {
  const requestedPaths: string[] = [];
  const requestedRequests: string[] = [];
  const requestedAccepts: string[] = [];
  const env: AssetBindings = {
    ASSETS: {
      fetch: async (request: Request) => {
        requestedPaths.push(new URL(request.url).pathname);
        requestedRequests.push(`${request.method} ${request.url}`);
        requestedAccepts.push(request.headers.get('accept') ?? '');
        return upstream();
      },
    },
    ENVIRONMENT: 'test',
  };
  return { env, requestedPaths, requestedRequests, requestedAccepts };
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
    // Boundary rows that look asset-ish but classify as SPA routes —
    // the fragile edge of the preserved legacy classification.
    ['/ASSETS/x', true, false],
    ['/assets', true, false],
    ['/foo/assets/bar', true, false],
    ['/a%2Eb', true, false],
  ];

  it('classifies static-vs-SPA exactly like the classifier service', () => {
    for (const [pathname, spaFallback] of corpus) {
      expect(classifier.isStaticAssetPath(pathname)).toBe(!spaFallback);
    }
  });

  it('routes SPA rows to /index.html and passes asset rows through unchanged', async () => {
    const accept = 'text/html,application/xhtml+xml';
    for (const [pathname, spaFallback] of corpus) {
      const { env, requestedPaths, requestedRequests, requestedAccepts } =
        makeEnv(
          () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
        );
      await worker.fetch(
        new Request(`https://admin.example${pathname}`, {
          headers: { accept },
        }),
        env,
      );
      const expectedPath = spaFallback ? '/index.html' : pathname;
      expect(requestedPaths).toEqual([expectedPath]);
      expect(requestedRequests).toEqual([
        `GET https://admin.example${expectedPath}`,
      ]);
      // The fallback rewrite (`new Request(new URL('/index.html', url),
      // request)`) forwards the original request headers — the Accept
      // header must survive both branches.
      expect(requestedAccepts).toEqual([accept]);
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
      expect(await res.text()).toBe('OK');
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
      const { env, requestedPaths, requestedRequests } = makeEnv(
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
      expect(requestedRequests).toEqual([
        `GET https://admin.example${pathname}`,
      ]);
      expect(res.status).toBe(status);
      expect(res.statusText).toBe('Upstream error');
      expect(await res.text()).toBe('missing');
      expect(headerSnapshot(res.headers)).toEqual(
        headerSnapshot(new Headers(UPSTREAM_ERROR_HEADERS)),
      );
    }
  });

  it('decorates sub-400 non-2xx asset responses like 2xx (redirects, not-modified, 399 boundary)', async () => {
    const sub400Rows: Array<[status: number, pathname: string]> = [
      [301, '/x.css'],
      [304, '/main.wasm'],
      [399, '/manifest.json'],
    ];
    for (const [status, pathname] of sub400Rows) {
      const { env, requestedPaths, requestedRequests } = makeEnv(
        // 301/304/399 with a null body: Response forbids bodies on
        // these in some runtimes, null is always legal.
        () => new Response(null, { status, headers: UPSTREAM_OK_HEADERS }),
      );
      const res = await worker.fetch(
        new Request(`https://admin.example${pathname}`),
        env,
      );
      expect(requestedPaths).toEqual([pathname]);
      expect(requestedRequests).toEqual([
        `GET https://admin.example${pathname}`,
      ]);
      expect(res.status).toBe(status);
      expect(headerSnapshot(res.headers)).toEqual(
        decoratedSnapshot(pathname, headerPolicy, cache),
      );
    }
  });

  it('decorates SPA fallback responses with the full header set regardless of status', async () => {
    for (const status of [200, 404]) {
      const { env, requestedPaths, requestedRequests } = makeEnv(
        () => new Response('shell', { status, headers: UPSTREAM_OK_HEADERS }),
      );
      const res = await worker.fetch(
        new Request('https://admin.example/settings'),
        env,
      );
      expect(requestedPaths).toEqual(['/index.html']);
      expect(requestedRequests).toEqual([
        'GET https://admin.example/index.html',
      ]);
      expect(res.status).toBe(status);
      expect(await res.text()).toBe('shell');
      expect(headerSnapshot(res.headers)).toEqual(
        decoratedSnapshot('/index.html', headerPolicy, cache),
      );
    }
  });

  it('bypasses the SPA fallback for non-GET methods (asset branch)', async () => {
    const methodRows: Array<[method: string, pathname: string]> = [
      ['POST', '/settings'],
      ['POST', '/'],
      ['HEAD', '/settings'],
      ['POST', '/main.dart.wasm'],
      ['HEAD', '/x.css'],
    ];
    for (const [method, pathname] of methodRows) {
      const { env, requestedPaths, requestedRequests } = makeEnv(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const res = await worker.fetch(
        new Request(`https://admin.example${pathname}`, { method }),
        env,
      );
      expect(requestedPaths).toEqual([pathname]);
      expect(requestedRequests).toEqual([
        `${method} https://admin.example${pathname}`,
      ]);
      expect(res.status).toBe(200);
      expect(headerSnapshot(res.headers)).toEqual(
        decoratedSnapshot(pathname, headerPolicy, cache),
      );
    }
  });

  it('strips the query string on the SPA fallback but forwards it on the asset branch', async () => {
    const { env: spaEnv, requestedPaths: spaPaths, requestedRequests: spaRequests } =
      makeEnv(() => new Response('shell', { status: 200, headers: UPSTREAM_OK_HEADERS }));
    const spaRes = await worker.fetch(
      new Request('https://admin.example/settings?token=x'),
      spaEnv,
    );
    expect(spaPaths).toEqual(['/index.html']);
    expect(spaRequests).toEqual(['GET https://admin.example/index.html']);
    expect(headerSnapshot(spaRes.headers)).toEqual(
      decoratedSnapshot('/index.html', headerPolicy, cache),
    );

    const {
      env: assetEnv,
      requestedPaths: assetPaths,
      requestedRequests: assetRequests,
    } = makeEnv(() => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }));
    const assetRes = await worker.fetch(
      new Request('https://admin.example/main.wasm?v=2'),
      assetEnv,
    );
    expect(assetPaths).toEqual(['/main.wasm']);
    expect(assetRequests).toEqual(['GET https://admin.example/main.wasm?v=2']);
    expect(assetRes.headers.get('Cache-Control')).toBe(
      'public, max-age=31536000, immutable',
    );
  });
});
