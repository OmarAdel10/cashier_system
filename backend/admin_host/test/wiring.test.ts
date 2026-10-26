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

// The one canonical full-set security-header oracle at the wired
// seam — verbatim hand copy of the legacy policy values (the
// index.test.ts asserts are non-canonical smoke checks; the unit
// layers keep their own full oracles).
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
  records: Array<{ url: string; method: string; auth: string; body: string }>;
} {
  const requestedUrls: string[] = [];
  const requestedMethods: string[] = [];
  const requestedAccepts: string[] = [];
  const requestedIfNoneMatch: string[] = [];
  const requestedAuthorizations: string[] = [];
  const requestedBodies: string[] = [];
  // Atomic per-call records: pushed synchronously at arrival, body
  // filled in place after the await — url/body/auth pairing is
  // intrinsic to the record and immune to resolution-order races
  // (unlike the parallel arrays above, whose push points differ).
  const records: Array<{ url: string; method: string; auth: string; body: string }> =
    [];
  const env: AssetBindings = {
    ASSETS: {
      fetch: async (request: Request) => {
        const record = {
          url: request.url,
          method: request.method,
          auth: request.headers.get('authorization') ?? '',
          body: '',
        };
        records.push(record);
        requestedUrls.push(request.url);
        requestedMethods.push(request.method);
        requestedAccepts.push(request.headers.get('accept') ?? '');
        requestedIfNoneMatch.push(request.headers.get('if-none-match') ?? '');
        requestedAuthorizations.push(request.headers.get('authorization') ?? '');
        // clone() branches the stream: reading the clone never
        // consumes the body the binding would forward.
        const body = await request.clone().text();
        requestedBodies.push(body);
        record.body = body;
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
    records,
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
    // The full immutable-extension set, end-to-end through the wired
    // seam (unit layers pin each member; here the routing + cache
    // composition must hold for every member).
    ['/x.mjs', false, true],
    ['/x.css', false, true],
    ['/x.woff2', false, true],
    ['/x.ttf', false, true],
    // Case-insensitive extension matching, end-to-end.
    ['/APP.JS', false, true],
    ['/main.WASM', false, true],
    // A literal /index.html request takes the ASSET branch (dot rule)
    // — the collision the split port makes unambiguous.
    ['/index.html', false, false],
    // Boundary rows: URL-parse fidelity at the seam. /a%2Eb is a
    // fallback row precisely because the handler feeds raw
    // url.pathname to the classifier — a handler switched to
    // decodeURIComponent(pathname) would flip this row to the asset
    // branch undetected. /a.b/main pins dot-in-dir (asset, hourly);
    // /assets/no-extension pins the /assets/ prefix arm without a dot.
    ['/a%2Eb', true, false],
    ['/a.b/main', false, false],
    ['/assets/no-extension', false, false],
    // /assets/ prefix boundary + case sensitivity: bare /assets and
    // mid-path /foo/assets/bar are NOT asset paths, and the prefix is
    // case-sensitive (/ASSETS/x).
    ['/ASSETS/x', true, false],
    ['/assets', true, false],
    ['/foo/assets/bar', true, false],
    // Shell-branch host fidelity: a // pathname WITHOUT a dot still
    // takes the fallback — and the binding must see the shell URL on
    // the ORIGINAL host, never a reconstruction of the raw pathname.
    ['//evil', true, false],
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
      // statusText must survive decoration at the wired seam (the
      // decorate path rebuilds the Response and could drop it).
      expect(res.statusText).toBe('Upstream OK');
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

  it('returns non-GET asset-branch responses with status >= 400 untouched', async () => {
    // The non-GET half of the ≥400 pin: a non-GET request to an SPA
    // route takes the asset branch, gets an upstream error, and must
    // ship without decoration (the recorded hardening gap to decide at
    // the DAFTARI-147 wiring decision — pinned as-is here).
    const methodErrorRows: Array<[method: string, pathname: string, status: number]> = [
      ['POST', '/settings', 404],
      ['HEAD', '/', 404],
      ['POST', '/x.css', 400],
    ];
    for (const [method, pathname, status] of methodErrorRows) {
      const { env, requestedUrls, requestedMethods } = makeEnv(
        () =>
          new Response('missing', {
            status,
            statusText: 'Upstream error',
            headers: UPSTREAM_ERROR_HEADERS,
          }),
      );
      const res = await worker.fetch(
        new Request(`https://admin.example${pathname}`, { method }),
        env,
      );
      expect(requestedUrls).toEqual([`https://admin.example${pathname}`]);
      expect(requestedMethods).toEqual([method]);
      expect(res.status).toBe(status);
      expect(res.statusText).toBe('Upstream error');
      expect(headerSnapshot(res.headers)).toEqual(
        headerSnapshot(new Headers(UPSTREAM_ERROR_HEADERS)),
      );
    }
  });

  it('decorates sub-400 non-2xx asset responses like 2xx (3xx + 399 boundary)', async () => {
    const sub400Rows: Array<[status: number, pathname: string, statusText: string, method: string]> = [
      [301, '/x.css', 'Moved Permanently', 'GET'],
      [304, '/main.wasm', '', 'GET'],
      [399, '/manifest.json', '', 'GET'],
      // Non-GET crosses the same 399 boundary on the asset branch —
      // decorated, not passed through.
      [399, '/x.css', '', 'POST'],
    ];
    for (const [status, pathname, statusText, method] of sub400Rows) {
      const { env, requestedUrls } = makeEnv(
        () => new Response(null, { status, statusText, headers: UPSTREAM_OK_HEADERS }),
      );
      const res = await worker.fetch(
        new Request(`https://admin.example${pathname}`, { method }),
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
    const methodRows: Array<[method: string, pathname: string, cacheControl: string]> = [
      ['POST', '/settings', HOURLY],
      ['POST', '/', HOURLY],
      ['HEAD', '/settings', HOURLY],
      // Real asset paths on the non-GET branch: immutable cache and
      // byte-fidelity at the binding (canary rows restored).
      ['POST', '/main.dart.wasm', IMMUTABLE],
      ['HEAD', '/x.css', IMMUTABLE],
    ];
    for (const [method, pathname, cacheControl] of methodRows) {
      const { env, requestedUrls, requestedMethods } = makeEnv(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const res = await worker.fetch(
        new Request(`https://admin.example${pathname}`, { method }),
        env,
      );
      expect(requestedUrls).toEqual([`https://admin.example${pathname}`]);
      expect(requestedMethods).toEqual([method]);
      expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(cacheControl));
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
    const { env, records } = makeEnv(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    // Overlapping requests through one shared module — two non-GET
    // asset-branch trips plus one GET shell rewrite — each must
    // forward its OWN body and Authorization header.
    //
    // Note on shell-body preservation: the Fetch spec forbids a body
    // on GET requests (undici throws at Request construction), and
    // the fallback branch is GET-only — so fetchShell's
    // body-preserving rewrite is vacuous by construction at this
    // seam; the POST-body forwarding test pins body survival on the
    // asset branch.
    const [resA, resB, resShell] = await Promise.all([
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
      worker.fetch(
        new Request('https://admin.example/settings', {
          headers: { authorization: 'Bearer token-shell' },
        }),
        env,
      ),
    ]);
    expect(resA.status).toBe(200);
    expect(resB.status).toBe(200);
    expect(resShell.status).toBe(200);
    // Arrival order is runtime-dependent for interleaved calls —
    // every assertion below is containment-based, never ordered.
    // Triples are built from the atomic per-call records (url, body,
    // auth captured on one object per call), so pairing is immune to
    // body-resolution-order races.
    const trips = records.map(
      (record) => `${record.url}|${record.body}|${record.auth}`,
    );
    expect(trips).toContain('https://admin.example/a.js|body-a|Bearer token-a');
    expect(trips).toContain('https://admin.example/b.js|body-b|Bearer token-b');
    // The shell rewrite forwards the original request's headers too —
    // the fallback trip carries the shell request's credentials.
    expect(trips).toContain(
      'https://admin.example/index.html||Bearer token-shell',
    );
    // Discrimination limit: capture-to-forward inside this handler is
    // synchronous, so the port doc's cross-tick overwrite hazard (a
    // shared adapter holding a request across event-loop ticks) is
    // unreachable through this test — the pin guards against
    // shared-state capture bugs, not tick-level interleavings.
  });
});
