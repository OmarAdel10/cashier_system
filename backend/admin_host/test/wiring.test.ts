import { describe, expect, it } from 'vitest';

import worker from '../src/index';
import type { AssetBindings } from '../src/index';

/**
 * Wiring tests: pin every docs/followups.md wiring obligation against
 * the WIRED handler (index.ts -> ServeRequestUseCase -> per-request
 * inline split-port adapter -> ASSETS binding). These obligations were
 * carried here from the deleted test/domain-parity.test.ts canary.
 *
 * Expected policy values are hand-copied change detectors (never
 * imported from the implementations) — a value drift in any service
 * fails these pins at the wired seam.
 *
 * Pinned here (canonical list: docs/followups.md):
 * - routing: SPA rows rewritten to /index.html, asset rows forwarded
 *   with the original URL, method, and full header set intact
 * - asset responses with status >= 400 returned untouched
 * - sub-400 non-2xx asset responses (3xx + the 399 boundary) decorated
 * - SPA-fallback responses decorated regardless of upstream status
 * - non-GET requests bypass the fallback (case-sensitive GET match)
 * - Cache-Control per branch (fallback hourly via the shell cache
 *   key, immutable set end-to-end, else hourly)
 * - hostile-upstream override precedence (upstream-only headers survive)
 * - query stripped by the SPA rewrite, forwarded on the asset branch
 * - request headers (Accept, If-None-Match) and body survive both
 *   branches
 * - case-insensitive extension matching end-to-end
 * - host preservation: an //evil.com-style pathname is NEVER rebuilt —
 *   the binding sees the original request URL byte-for-byte
 * - method forwarding to the binding
 * - per-request adapter lifetime: interleaved requests each forward
 *   their own body and credentials through one shared module
 * - shell path == cache key (/index.html)
 */

const HOURLY = 'public, max-age=3600';
const IMMUTABLE = 'public, max-age=31536000, immutable';

// The one canonical security-header oracle for the wiring tests —
// verbatim hand copy of the legacy policy values.
const SECURITY_HEADERS: Record<string, string> = {
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
    "style-src 'self' 'unsafe-inline'; font-src 'self' data:; " +
    "img-src 'self' data:; connect-src 'self' " +
    'https://*.daftariapp.workers.dev wss://*.daftariapp.workers.dev ' +
    'https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com; ' +
    "frame-src 'self' https://*.firebaseapp.com; frame-ancestors 'none'",
};

// Hostile upstream values: the wired handler must OVERRIDE these with
// the policy values, while the non-conflicting upstream headers
// (Content-Type, ETag) survive.
const UPSTREAM_OK_HEADERS: Record<string, string> = {
  'Content-Type': 'application/javascript',
  ETag: '"etag-demo"',
  'X-Frame-Options': 'SAMEORIGIN',
  'Cache-Control': 'no-store',
};

const UPSTREAM_ERROR_HEADERS: Record<string, string> = {
  'Content-Type': 'text/plain',
};

function makeEnv(upstream: () => Response): {
  env: AssetBindings;
  requestedUrls: string[];
  requestedMethods: string[];
  requestedAccepts: string[];
  requestedIfNoneMatch: string[];
  requestedAuthorizations: string[];
  requestedBodies: string[];
} {
  const requestedUrls: string[] = [];
  const requestedMethods: string[] = [];
  const requestedAccepts: string[] = [];
  const requestedIfNoneMatch: string[] = [];
  const requestedAuthorizations: string[] = [];
  const requestedBodies: string[] = [];
  const env: AssetBindings = {
    ASSETS: {
      fetch: async (request: Request) => {
        requestedUrls.push(request.url);
        requestedMethods.push(request.method);
        requestedAccepts.push(request.headers.get('accept') ?? '');
        requestedIfNoneMatch.push(request.headers.get('if-none-match') ?? '');
        requestedAuthorizations.push(request.headers.get('authorization') ?? '');
        // clone() branches the stream: reading the clone never
        // consumes the body the binding would forward.
        requestedBodies.push(await request.clone().text());
        return upstream();
      },
    },
    ENVIRONMENT: 'test',
  };
  return {
    env,
    requestedUrls,
    requestedMethods,
    requestedAccepts,
    requestedIfNoneMatch,
    requestedAuthorizations,
    requestedBodies,
  };
}

function headerSnapshot(headers: Headers): Record<string, string> {
  const snapshot: Record<string, string> = {};
  headers.forEach((value, name) => {
    snapshot[name] = value;
  });
  return snapshot;
}

/** Expected final header set: upstream copy + policy overrides + CC. */
function decoratedExpected(cacheControl: string): Record<string, string> {
  const expected = new Headers(UPSTREAM_OK_HEADERS);
  for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
    expected.set(name, value);
  }
  expected.set('Cache-Control', cacheControl);
  return headerSnapshot(expected);
}

describe('admin host wiring (thin handler -> use case -> inline adapter)', () => {
  const corpus: Array<[pathname: string, spaFallback: boolean, immutable: boolean]> = [
    ['/main.wasm', false, true],
    ['/assets/app.js', false, true],
    ['/manifest.json', false, false],
    // Case-insensitive extension matching, end-to-end.
    ['/APP.JS', false, true],
    ['/main.WASM', false, true],
    // A literal /index.html request takes the ASSET branch (dot rule)
    // — the collision the split port makes unambiguous.
    ['/index.html', false, false],
    ['/', true, false],
    ['/settings', true, false],
    ['/users/42/profile', true, false],
  ];

  it('routes SPA rows to /index.html and asset rows through unchanged', async () => {
    const accept = 'text/html,application/xhtml+xml';
    const ifNoneMatch = '"etag-demo"';
    for (const [pathname, spaFallback] of corpus) {
      const { env, requestedUrls, requestedMethods, requestedAccepts, requestedIfNoneMatch } =
        makeEnv(() => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }));
      await worker.fetch(
        new Request(`https://admin.example${pathname}`, {
          headers: { accept, 'if-none-match': ifNoneMatch },
        }),
        env,
      );
      expect(requestedUrls).toEqual([
        spaFallback
          ? 'https://admin.example/index.html'
          : `https://admin.example${pathname}`,
      ]);
      expect(requestedMethods).toEqual(['GET']);
      // The rewrite (new Request(new URL('/index.html', request.url),
      // request)) forwards the original request headers — Accept and
      // the conditional If-None-Match must survive both branches.
      expect(requestedAccepts).toEqual([accept]);
      expect(requestedIfNoneMatch).toEqual([ifNoneMatch]);
    }
  });

  it('applies the cache policy per branch (shell cache key == /index.html)', async () => {
    for (const [pathname, spaFallback, immutable] of corpus) {
      const { env } = makeEnv(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const res = await worker.fetch(
        new Request(`https://admin.example${pathname}`),
        env,
      );
      expect(res.status).toBe(200);
      expect(await res.text()).toBe('OK');
      const cacheControl = spaFallback || !immutable ? HOURLY : IMMUTABLE;
      expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(cacheControl));
    }
  });

  it('returns asset responses with status >= 400 untouched', async () => {
    const errorRows: Array<[status: number, pathname: string]> = [
      [400, '/x.css'],
      [404, '/main.wasm'],
      [500, '/assets/app.js'],
    ];
    for (const [status, pathname] of errorRows) {
      const { env, requestedUrls } = makeEnv(
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
      expect(requestedUrls).toEqual([`https://admin.example${pathname}`]);
      expect(res.status).toBe(status);
      expect(res.statusText).toBe('Upstream error');
      expect(await res.text()).toBe('missing');
      expect(headerSnapshot(res.headers)).toEqual(
        headerSnapshot(new Headers(UPSTREAM_ERROR_HEADERS)),
      );
    }
  });

  it('decorates sub-400 non-2xx asset responses like 2xx (3xx + 399 boundary)', async () => {
    const sub400Rows: Array<[status: number, pathname: string, statusText: string]> = [
      [301, '/x.css', 'Moved Permanently'],
      [304, '/main.wasm', ''],
      [399, '/manifest.json', ''],
    ];
    for (const [status, pathname, statusText] of sub400Rows) {
      const { env, requestedUrls } = makeEnv(
        () => new Response(null, { status, statusText, headers: UPSTREAM_OK_HEADERS }),
      );
      const res = await worker.fetch(
        new Request(`https://admin.example${pathname}`),
        env,
      );
      expect(requestedUrls).toEqual([`https://admin.example${pathname}`]);
      expect(res.status).toBe(status);
      expect(res.statusText).toBe(statusText);
      const cacheControl = pathname === '/manifest.json' ? HOURLY : IMMUTABLE;
      expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(cacheControl));
    }
  });

  it('decorates SPA fallback responses regardless of upstream status', async () => {
    for (const status of [200, 404, 500]) {
      const { env, requestedUrls } = makeEnv(
        () => new Response('shell', { status, headers: UPSTREAM_OK_HEADERS }),
      );
      const res = await worker.fetch(
        new Request('https://admin.example/settings'),
        env,
      );
      expect(requestedUrls).toEqual(['https://admin.example/index.html']);
      expect(res.status).toBe(status);
      expect(await res.text()).toBe('shell');
      // Shell path == cache key: the fallback is hourly because the
      // cache policy is keyed on /index.html, not on /settings.
      expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(HOURLY));
    }
  });

  it('bypasses the SPA fallback for non-GET methods (case-sensitive GET)', async () => {
    // Note: the Fetch spec uppercases methods at Request construction,
    // so lowercase 'get' never reaches the presentation boundary — the
    // case-sensitivity contract is pinned at the unit layer, where the
    // DTO is constructed directly. Here only real runtime methods
    // can occur.
    const methodRows: Array<[method: string, pathname: string]> = [
      ['POST', '/settings'],
      ['POST', '/'],
      ['HEAD', '/settings'],
    ];
    for (const [method, pathname] of methodRows) {
      const { env, requestedUrls, requestedMethods } = makeEnv(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const res = await worker.fetch(
        new Request(`https://admin.example${pathname}`, { method }),
        env,
      );
      expect(requestedUrls).toEqual([`https://admin.example${pathname}`]);
      expect(requestedMethods).toEqual([method]);
      expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(HOURLY));
    }
  });

  it('overrides hostile upstream headers and lets upstream-only headers survive', async () => {
    const { env } = makeEnv(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const res = await worker.fetch(
      new Request('https://admin.example/main.wasm'),
      env,
    );
    // Policy overrides win over the hostile upstream values...
    expect(res.headers.get('X-Frame-Options')).toBe('DENY');
    expect(res.headers.get('Cache-Control')).toBe(IMMUTABLE);
    // ...while the non-conflicting upstream headers survive.
    expect(res.headers.get('Content-Type')).toBe('application/javascript');
    expect(res.headers.get('ETag')).toBe('"etag-demo"');
  });

  it('strips the query on the SPA rewrite but forwards it on the asset branch', async () => {
    const {
      env: spaEnv,
      requestedUrls: spaUrls,
    } = makeEnv(() => new Response('shell', { status: 200, headers: UPSTREAM_OK_HEADERS }));
    await worker.fetch(new Request('https://admin.example/settings?token=x'), spaEnv);
    expect(spaUrls).toEqual(['https://admin.example/index.html']);

    const {
      env: assetEnv,
      requestedUrls: assetUrls,
    } = makeEnv(() => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }));
    const assetRes = await worker.fetch(
      new Request('https://admin.example/main.wasm?v=2'),
      assetEnv,
    );
    expect(assetUrls).toEqual(['https://admin.example/main.wasm?v=2']);
    expect(assetRes.headers.get('Cache-Control')).toBe(IMMUTABLE);
  });

  it('forwards the request body to the binding on non-GET passthrough', async () => {
    const { env, requestedBodies, requestedUrls } = makeEnv(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    await worker.fetch(
      new Request('https://admin.example/settings', {
        method: 'POST',
        body: 'payload data',
      }),
      env,
    );
    expect(requestedUrls).toEqual(['https://admin.example/settings']);
    expect(requestedBodies).toEqual(['payload data']);
  });

  it('never rebuilds // host-swapping pathnames (host preservation)', async () => {
    const { env, requestedUrls } = makeEnv(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    await worker.fetch(new Request('https://admin.example//evil.com/x.js'), env);
    // The binding saw the ORIGINAL URL byte-for-byte — the pathname
    // was never decoded, normalized, or reconstructed (it classifies
    // as an asset via the dot rule and forwards verbatim).
    expect(requestedUrls).toEqual(['https://admin.example//evil.com/x.js']);
  });

  it('forwards each interleaved request its own body and credentials (per-request adapter lifetime)', async () => {
    const { env, requestedBodies, requestedAuthorizations, requestedUrls } = makeEnv(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    // Two overlapping non-GET asset-branch requests through one shared
    // module: each must forward its OWN body and Authorization header.
    const [resA, resB] = await Promise.all([
      worker.fetch(
        new Request('https://admin.example/a.js', {
          method: 'POST',
          body: 'body-a',
          headers: { authorization: 'Bearer token-a' },
        }),
        env,
      ),
      worker.fetch(
        new Request('https://admin.example/b.js', {
          method: 'POST',
          body: 'body-b',
          headers: { authorization: 'Bearer token-b' },
        }),
        env,
      ),
    ]);
    expect(resA.status).toBe(200);
    expect(resB.status).toBe(200);
    expect(requestedUrls).toEqual([
      'https://admin.example/a.js',
      'https://admin.example/b.js',
    ]);
    // Order of arrival is runtime-dependent for truly interleaved
    // calls, but each request's OWN body must pair with its OWN
    // credentials — assert the two (url, body, auth) triples.
    const trips = requestedUrls.map(
      (url, i) => `${url}|${requestedBodies[i]}|${requestedAuthorizations[i]}`,
    );
    expect(trips).toContain('https://admin.example/a.js|body-a|Bearer token-a');
    expect(trips).toContain('https://admin.example/b.js|body-b|Bearer token-b');
    expect(requestedBodies).toContain('body-a');
    expect(requestedBodies).toContain('body-b');
  });
});
