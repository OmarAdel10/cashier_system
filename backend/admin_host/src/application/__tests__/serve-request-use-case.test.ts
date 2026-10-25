import { describe, expect, it } from 'vitest';

import type { AssetFetcher } from '../ports/asset-fetcher';
import type { ServeRequestDto } from '../dtos/serve-request-dto';
import { CachePolicyServiceImpl } from '../../domain/services/cache-policy-service.impl';
import { HeaderPolicyServiceImpl } from '../../domain/services/header-policy-service.impl';
import { StaticAssetClassifierImpl } from '../../domain/services/static-asset-classifier.impl';
import type {
  CachePolicyService,
} from '../../domain/services/cache-policy-service';
import type {
  HeaderPolicyService,
} from '../../domain/services/header-policy-service';
import type {
  StaticAssetClassifier,
} from '../../domain/services/static-asset-classifier';
import { ServeRequestUseCase } from '../use-cases/serve-request-use-case';

// Verbatim legacy policy copies — deliberate change detectors, never
// imported from the impls (anti-tautology, same discipline as the
// domain tests).
const HOURLY = 'public, max-age=3600';
const IMMUTABLE = 'public, max-age=31536000, immutable';
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
    "style-src 'self' 'unsafe-inline'; " +
    "font-src 'self' data:; img-src 'self' data:; " +
    "connect-src 'self' https://*.daftariapp.workers.dev wss://*.daftariapp.workers.dev " +
    'https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com; ' +
    "frame-src 'self' https://*.firebaseapp.com; " +
    "frame-ancestors 'none'",
};

// Hostile upstream values: the use case must OVERRIDE these with the
// domain policy values, not merge them — while upstream-only headers
// (Content-Type, ETag) survive untouched.
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

function makeFetcher(upstream: () => Response): {
  fetcher: AssetFetcher;
  calls: string[];
  upstreams: Response[];
} {
  const calls: string[] = [];
  const upstreams: Response[] = [];
  const serve = () => {
    const response = upstream();
    upstreams.push(response);
    return response;
  };
  // Split-port mock: the branch taken is the observable — 'shell'
  // (fetchShell, SPA fallback) or 'original' (forwardOriginal, asset
  // branch). No pathname crosses the fetch seam anymore.
  const fetcher: AssetFetcher = {
    fetchShell: async () => {
      calls.push('shell');
      return serve();
    },
    forwardOriginal: async () => {
      calls.push('original');
      return serve();
    },
  };
  return { fetcher, calls, upstreams };
}

function makeUseCase(
  fetcher: AssetFetcher,
  overrides?: {
    cachePolicy?: CachePolicyService;
    headerPolicy?: HeaderPolicyService;
    classifier?: StaticAssetClassifier;
  },
): ServeRequestUseCase {
  return new ServeRequestUseCase({
    fetcher,
    cachePolicy:
      overrides?.cachePolicy ?? new CachePolicyServiceImpl(),
    headerPolicy:
      overrides?.headerPolicy ?? new HeaderPolicyServiceImpl(),
    classifier:
      overrides?.classifier ?? new StaticAssetClassifierImpl(),
  });
}

/** Expected decorated headers: copy of upstream + policy overrides + CC. */
function decoratedExpected(cacheControl: string): Record<string, string> {
  const expected = new Headers(UPSTREAM_OK_HEADERS);
  for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
    expected.set(name, value);
  }
  expected.set('Cache-Control', cacheControl);
  return headerSnapshot(expected);
}

describe('ServeRequestUseCase', () => {
  it('serves the SPA shell for GET / with hourly cache and full headers', async () => {
    const { fetcher, calls } = makeFetcher(
      () =>
        new Response('shell', {
          status: 200,
          statusText: 'Upstream OK',
          headers: UPSTREAM_OK_HEADERS,
        }),
    );
    const useCase = makeUseCase(fetcher);
    const res = await useCase.execute({ method: 'GET', pathname: '/' });
    expect(calls).toEqual(['shell']);
    expect(res.status).toBe(200);
    expect(res.statusText).toBe('Upstream OK');
    expect(await res.text()).toBe('shell');
    expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(HOURLY));
  });

  it('serves the SPA shell for GET on non-asset routes', async () => {
    for (const pathname of ['/settings', '/users/42/profile']) {
      const { fetcher, calls } = makeFetcher(
        () => new Response('shell', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const useCase = makeUseCase(fetcher);
      const res = await useCase.execute({ method: 'GET', pathname });
      expect(calls).toEqual(['shell']);
      expect(res.headers.get('Cache-Control')).toBe(HOURLY);
    }
  });

  it('serves assets through the port verbatim with the policy cache', async () => {
    const { fetcher, calls } = makeFetcher(
      () =>
        new Response('OK', {
          status: 200,
          statusText: 'Upstream OK',
          headers: UPSTREAM_OK_HEADERS,
        }),
    );
    const useCase = makeUseCase(fetcher);
    const res = await useCase.execute({
      method: 'GET',
      pathname: '/main.wasm',
    });
    expect(calls).toEqual(['original']);
    expect(res.status).toBe(200);
    expect(res.statusText).toBe('Upstream OK');
    expect(await res.text()).toBe('OK');
    expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(IMMUTABLE));
  });

  it('applies the immutable cache case-insensitively end-to-end', async () => {
    for (const pathname of ['/APP.JS', '/main.WASM']) {
      const { fetcher } = makeFetcher(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const useCase = makeUseCase(fetcher);
      const res = await useCase.execute({ method: 'GET', pathname });
      expect(res.headers.get('Cache-Control')).toBe(IMMUTABLE);
    }
  });

  it('returns asset responses with status >= 400 untouched', async () => {
    const errorRows: Array<[status: number, pathname: string]> = [
      [400, '/x.css'],
      [404, '/main.wasm'],
      [500, '/assets/app.js'],
    ];
    for (const [status, pathname] of errorRows) {
      const { fetcher, calls, upstreams } = makeFetcher(
        () =>
          new Response('missing', {
            status,
            statusText: 'Upstream error',
            headers: UPSTREAM_ERROR_HEADERS,
          }),
      );
      const useCase = makeUseCase(fetcher);
      const res = await useCase.execute({ method: 'GET', pathname });
      expect(calls).toEqual(['original']);
      expect(res.status).toBe(status);
      expect(res.statusText).toBe('Upstream error');
      expect(await res.text()).toBe('missing');
      // Identity pin: the exact upstream Response object is
      // returned, not a rewrapped clone (header multiplicity and
      // stream identity preserved).
      expect(res).toBe(upstreams[0]);
      expect(headerSnapshot(res.headers)).toEqual(
        headerSnapshot(new Headers(UPSTREAM_ERROR_HEADERS)),
      );
    }
  });

  it('decorates sub-400 non-2xx asset responses like 2xx', async () => {
    const sub400Rows: Array<
      [status: number, pathname: string, statusText: string, cache: string]
    > = [
      [301, '/x.css', 'Moved Permanently', IMMUTABLE],
      [304, '/main.wasm', '', IMMUTABLE],
      [399, '/manifest.json', '', HOURLY],
    ];
    for (const [status, pathname, statusText, cache] of sub400Rows) {
      const { fetcher } = makeFetcher(
        // Null body is always legal for any status.
        () =>
          new Response(null, { status, statusText, headers: UPSTREAM_OK_HEADERS }),
      );
      const useCase = makeUseCase(fetcher);
      const res = await useCase.execute({ method: 'GET', pathname });
      expect(res.status).toBe(status);
      expect(res.statusText).toBe(statusText);
      expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(cache));
    }
  });

  it('decorates SPA fallback responses regardless of upstream status', async () => {
    const fallbackRows: Array<
      [status: number, statusText: string, body: string | null]
    > = [
      [200, 'Upstream OK', 'shell'],
      // A null body is always legal for any status — 304 must not
      // carry one.
      [304, '', null],
      [404, 'Not Found', 'shell'],
      [500, 'Server Error', 'shell'],
    ];
    for (const [status, statusText, body] of fallbackRows) {
      const { fetcher } = makeFetcher(
        () =>
          new Response(body, {
            status,
            statusText,
            headers: UPSTREAM_OK_HEADERS,
          }),
      );
      const useCase = makeUseCase(fetcher);
      const res = await useCase.execute({
        method: 'GET',
        pathname: '/settings',
      });
      expect(res.status).toBe(status);
      expect(res.statusText).toBe(statusText);
      expect(await res.text()).toBe(body ?? '');
      expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(HOURLY));
    }
  });

  it('bypasses the SPA fallback for non-GET methods (asset branch)', async () => {
    const methodRows: Array<[method: string, pathname: string, cache: string]> = [
      ['POST', '/settings', HOURLY],
      ['POST', '/', HOURLY],
      ['HEAD', '/settings', HOURLY],
      ['POST', '/main.dart.wasm', IMMUTABLE],
      ['HEAD', '/x.css', IMMUTABLE],
      // Method matching is case-sensitive (preserved legacy
      // behavior, documented in the DTO) — lowercase variants take
      // the asset branch.
      ['get', '/settings', HOURLY],
      ['Get', '/', HOURLY],
      // /assets/ prefix without an extension still classifies as an
      // asset (the OR rule's prefix arm) — hourly, not fallback.
      ['GET', '/assets/noext', HOURLY],
    ];
    for (const [method, pathname, cache] of methodRows) {
      const { fetcher, calls } = makeFetcher(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const useCase = makeUseCase(fetcher);
      const res = await useCase.execute({ method, pathname });
      expect(calls).toEqual(['original']);
      expect(res.status).toBe(200);
      expect(res.headers.get('Cache-Control')).toBe(cache);
      expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(cache));
    }
  });

  it('returns non-GET asset-branch errors untouched', async () => {
    const { fetcher, calls, upstreams } = makeFetcher(
      () =>
        new Response('missing', {
          status: 404,
          statusText: 'Upstream error',
          headers: UPSTREAM_ERROR_HEADERS,
        }),
    );
    const useCase = makeUseCase(fetcher);
    const res = await useCase.execute({
      method: 'POST',
      pathname: '/settings',
    });
    expect(calls).toEqual(['original']);
    expect(res.status).toBe(404);
    expect(res.statusText).toBe('Upstream error');
    expect(await res.text()).toBe('missing');
    // Identity pin: exact upstream Response object, not a clone.
    expect(res).toBe(upstreams[0]);
    expect(headerSnapshot(res.headers)).toEqual(
      headerSnapshot(new Headers(UPSTREAM_ERROR_HEADERS)),
    );
  });

  it('overrides hostile upstream headers, keeps upstream-only headers', async () => {
    const { fetcher } = makeFetcher(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const useCase = makeUseCase(fetcher);
    const res = await useCase.execute({
      method: 'GET',
      pathname: '/main.wasm',
    });
    expect(res.headers.get('X-Frame-Options')).toBe('DENY');
    expect(res.headers.get('Cache-Control')).toBe(IMMUTABLE);
    expect(res.headers.get('Content-Type')).toBe('application/javascript');
    expect(res.headers.get('ETag')).toBe('"etag-demo"');
  });

  it('routes through the injected services, not hidden defaults', async () => {
    // Stub cache policy: the response must carry the stub's marker.
    const { fetcher } = makeFetcher(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const useCase = makeUseCase(fetcher, {
      cachePolicy: { cacheControlFor: () => 'stub-cache-directive' },
    });
    const res = await useCase.execute({
      method: 'GET',
      pathname: '/main.wasm',
    });
    expect(res.headers.get('Cache-Control')).toBe('stub-cache-directive');

    // Flipped classifier: a dot path must fall back to the shell.
    const { fetcher: fallbackFetcher, calls } = makeFetcher(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const flipped = makeUseCase(fallbackFetcher, {
      classifier: {
        isStaticAssetPath: () => false,
        extOf: () => '',
      },
    });
    await flipped.execute({ method: 'GET', pathname: '/main.wasm' });
    expect(calls).toEqual(['shell']);

    // Recording cache stub on the asset branch: the cache key is the
    // command pathname (the fallback counterpart is pinned in the
    // shell-cache-key test below).
    const { fetcher: assetFetcher } = makeFetcher(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const assetSeen: string[] = [];
    const recording = makeUseCase(assetFetcher, {
      cachePolicy: {
        cacheControlFor: (pathname: string) => {
          assetSeen.push(pathname);
          return IMMUTABLE;
        },
      },
    });
    await recording.execute({ method: 'GET', pathname: '/main.wasm' });
    expect(assetSeen).toEqual(['/main.wasm']);
  });

  it('routes header overrides through the injected header policy', async () => {
    const { fetcher } = makeFetcher(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const useCase = makeUseCase(fetcher, {
      headerPolicy: { securityHeaders: () => ({ 'X-Stub-Header': 'stub' }) },
    });
    const res = await useCase.execute({
      method: 'GET',
      pathname: '/main.wasm',
    });
    expect(res.headers.get('X-Stub-Header')).toBe('stub');
    // The injected stub is the override source — no hidden default
    // re-adds the real security headers, so the hostile upstream
    // value survives untouched.
    expect(res.headers.get('X-Frame-Options')).toBe('SAMEORIGIN');

    // Fallback branch: the stub policy is the override source there
    // too — the shell response carries the stub marker, and the
    // hostile upstream value survives instead of the real DENY.
    const { fetcher: shellFetcher } = makeFetcher(
      () =>
        new Response('shell', {
          status: 200,
          headers: UPSTREAM_OK_HEADERS,
        }),
    );
    const shellUseCase = makeUseCase(shellFetcher, {
      headerPolicy: { securityHeaders: () => ({ 'X-Stub-Header': 'stub' }) },
    });
    const shellRes = await shellUseCase.execute({
      method: 'GET',
      pathname: '/settings',
    });
    expect(shellRes.headers.get('X-Stub-Header')).toBe('stub');
    expect(shellRes.headers.get('X-Frame-Options')).toBe('SAMEORIGIN');
  });

  it('keeps the cache policy authoritative when the header policy carries a Cache-Control key', async () => {
    const { fetcher } = makeFetcher(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const useCase = makeUseCase(fetcher, {
      headerPolicy: {
        securityHeaders: () => ({ 'Cache-Control': 'stub-cc' }),
      },
    });
    const res = await useCase.execute({
      method: 'GET',
      pathname: '/main.wasm',
    });
    // decorate() sets Cache-Control last, so a colliding
    // header-policy entry cannot beat the cache policy.
    expect(res.headers.get('Cache-Control')).toBe(IMMUTABLE);
  });

  it('propagates collaborator errors, not just fetch rejections', async () => {
    const { fetcher } = makeFetcher(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const useCase = makeUseCase(fetcher, {
      classifier: {
        isStaticAssetPath: () => {
          throw new Error('classifier broke');
        },
        extOf: () => '',
      },
    });
    // No hidden try/catch: legacy has none either — any exception on
    // the serve path escapes raw (see docs/followups.md, DAFTARI-147
    // exception-path note).
    await expect(
      useCase.execute({ method: 'GET', pathname: '/main.wasm' }),
    ).rejects.toThrow('classifier broke');
  });

  it('propagates upstream fetch rejections on the fallback branch', async () => {
    const fetcher: AssetFetcher = {
      fetchShell: async () => {
        throw new Error('upstream down');
      },
      forwardOriginal: async () => {
        throw new Error('upstream down');
      },
    };
    const useCase = makeUseCase(fetcher);
    await expect(
      useCase.execute({ method: 'GET', pathname: '/settings' }),
    ).rejects.toThrow('upstream down');
  });

  it('propagates upstream fetch rejections on the asset branch', async () => {
    const fetcher: AssetFetcher = {
      fetchShell: async () => {
        throw new Error('upstream down');
      },
      forwardOriginal: async () => {
        throw new Error('upstream down');
      },
    };
    const useCase = makeUseCase(fetcher);
    await expect(
      useCase.execute({ method: 'GET', pathname: '/main.wasm' }),
    ).rejects.toThrow('upstream down');
  });

  it('passes the command pathname to the classifier unmodified', async () => {
    const { fetcher } = makeFetcher(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const seen: string[] = [];
    const useCase = makeUseCase(fetcher, {
      classifier: {
        isStaticAssetPath: (pathname: string) => {
          seen.push(pathname);
          return true;
        },
        extOf: () => '',
      },
    });
    await useCase.execute({ method: 'GET', pathname: '/main.wasm' });
    expect(seen).toEqual(['/main.wasm']);
  });

  it('returns hourly cache for the fallback shell via the cache policy', async () => {
    const { fetcher } = makeFetcher(
      () => new Response('shell', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const seenKeys: string[] = [];
    const useCase = makeUseCase(fetcher, {
      cachePolicy: {
        cacheControlFor: (pathname: string) => {
          seenKeys.push(pathname);
          return HOURLY;
        },
      },
    });
    const res = await useCase.execute({ method: 'GET', pathname: '/settings' });
    // The fallback branch asks the cache policy for the SHELL path,
    // not the original route path.
    expect(seenKeys).toEqual(['/index.html']);
    expect(res.headers.get('Cache-Control')).toBe(HOURLY);
  });

  it('serves a literal GET /index.html through the asset branch, not the shell', async () => {
    // The round-4 collision pin: a literal /index.html request takes
    // the ASSET branch (dot rule) via forwardOriginal — never the
    // shell fetch. The two fetches are now different port methods, so
    // the ambiguity a single fetch(pathname) had is unrepresentable.
    const { fetcher, calls } = makeFetcher(
      () => new Response('shell-file', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const useCase = makeUseCase(fetcher);
    const res = await useCase.execute({ method: 'GET', pathname: '/index.html' });
    expect(calls).toEqual(['original']);
    expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(HOURLY));

    // The >= 400 half: identity passthrough on the same literal path.
    const { fetcher: errFetcher, calls: errCalls, upstreams: errUps } = makeFetcher(
      () => new Response('missing', { status: 404, headers: UPSTREAM_ERROR_HEADERS }),
    );
    const errUseCase = makeUseCase(errFetcher);
    const errRes = await errUseCase.execute({
      method: 'GET',
      pathname: '/index.html',
    });
    expect(errCalls).toEqual(['original']);
    expect(errRes).toBe(errUps[0]);
  });

  it('never consults the classifier for non-GET requests or GET /', async () => {
    // Legacy short-circuit (src/index.ts): method !== 'GET' never
    // reaches the classifier; GET / satisfies the '/' arm before the
    // classifier runs. A throwing classifier proves the skip.
    const throwingClassifier = {
      isStaticAssetPath: (): boolean => {
        throw new Error('classifier broke');
      },
      extOf: (): string => '',
    };
    for (const [method, pathname, expectedCall] of [
      ['POST', '/settings', 'original'],
      ['HEAD', '/x.css', 'original'],
      ['get', '/settings', 'original'],
      ['GET', '/', 'shell'],
    ] as const) {
      const { fetcher, calls } = makeFetcher(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const useCase = makeUseCase(fetcher, { classifier: throwingClassifier });
      const res = await useCase.execute({ method, pathname });
      expect(calls).toEqual([expectedCall]);
      expect(res.status).toBe(200);
    }

    // Recording classifier + GET /: never called at all.
    const { fetcher: rootFetcher } = makeFetcher(
      () => new Response('shell', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const seen: string[] = [];
    const root = makeUseCase(rootFetcher, {
      classifier: {
        isStaticAssetPath: (pathname: string) => {
          seen.push(pathname);
          return true;
        },
        extOf: () => '',
      },
    });
    await root.execute({ method: 'GET', pathname: '/' });
    expect(seen).toEqual([]);
  });

  it('decorates without consuming or mutating the upstream response', async () => {
    // Asset branch: the upstream body stream is moved into the
    // decorated response, never read — bodyUsed stays false on the
    // upstream object, and the upstream headers keep their hostile
    // values (copy semantics, not mutation).
    const { fetcher, upstreams } = makeFetcher(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const useCase = makeUseCase(fetcher);
    const res = await useCase.execute({ method: 'GET', pathname: '/main.wasm' });
    const upstream = upstreams[0];
    if (!upstream) {
      throw new Error('test bug: upstream not recorded');
    }
    expect(res).not.toBe(upstream);
    expect(upstream.bodyUsed).toBe(false);
    expect(upstream.headers.get('X-Frame-Options')).toBe('SAMEORIGIN');
    expect(upstream.headers.get('Cache-Control')).toBe('no-store');
    expect(res.headers.get('X-Frame-Options')).toBe('DENY');

    // Fallback branch: same copy semantics on the shell fetch.
    const { fetcher: shellFetcher, upstreams: shellUps } = makeFetcher(
      () => new Response('shell', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const shellUseCase = makeUseCase(shellFetcher);
    const shellRes = await shellUseCase.execute({
      method: 'GET',
      pathname: '/settings',
    });
    const shellUpstream = shellUps[0];
    if (!shellUpstream) {
      throw new Error('test bug: shell upstream not recorded');
    }
    expect(shellRes).not.toBe(shellUpstream);
    expect(shellUpstream.bodyUsed).toBe(false);
    expect(shellUpstream.headers.get('Cache-Control')).toBe('no-store');
  });

  it('routes raw hostile-looking pathnames per the classification rules', async () => {
    // The M2 hazard pin: a // -prefixed dotted pathname classifies
    // as an asset (dot rule) and reaches forwardOriginal — the use
    // case never rebuilds a URL from it (no pathname crosses the
    // fetch seam at all). Byte fidelity to the binding is a wiring
    // pin. /a%2Eb stays encoded — no dot, SPA fallback.
    for (const [pathname, expectedCall] of [
      ['//evil.com/x.js', 'original'],
      ['/a%2Eb', 'shell'],
    ] as const) {
      const { fetcher, calls } = makeFetcher(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const useCase = makeUseCase(fetcher);
      const res = await useCase.execute({ method: 'GET', pathname });
      expect(calls).toEqual([expectedCall]);
      expect(res.status).toBe(200);
    }
  });

  it('propagates header-policy throws from the decorate path on both branches', async () => {
    // A scoped try/catch around decorate (the security-header path)
    // would swallow this and ship undecorated responses — these pins
    // are the regression guard (round-4 coverage Medium).
    for (const [method, pathname, expectedCall] of [
      ['GET', '/main.wasm', 'original'],
      ['GET', '/settings', 'shell'],
    ] as const) {
      const { fetcher, calls } = makeFetcher(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const useCase = makeUseCase(fetcher, {
        headerPolicy: {
          securityHeaders: () => {
            throw new Error('hp broke');
          },
        },
      });
      await expect(
        useCase.execute({ method, pathname }),
      ).rejects.toThrow('hp broke');
      expect(calls).toEqual([expectedCall]);
    }
  });

  it('propagates cache-policy throws from the decorate path on both branches', async () => {
    for (const [method, pathname, expectedCall] of [
      ['GET', '/main.wasm', 'original'],
      ['GET', '/settings', 'shell'],
    ] as const) {
      const { fetcher, calls } = makeFetcher(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const useCase = makeUseCase(fetcher, {
        cachePolicy: {
          cacheControlFor: () => {
            throw new Error('cp broke');
          },
        },
      });
      await expect(
        useCase.execute({ method, pathname }),
      ).rejects.toThrow('cp broke');
      expect(calls).toEqual([expectedCall]);
    }
  });

  it('keeps upstream headers intact when the header policy returns an empty map', async () => {
    // The zero-iteration decorate loop: an empty securityHeaders() must
    // leave every upstream header untouched (hostile values survive)
    // while Cache-Control still comes from the cache policy.
    const { fetcher, calls } = makeFetcher(
      () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
    );
    const useCase = makeUseCase(fetcher, {
      headerPolicy: { securityHeaders: () => ({}) },
    });
    const res = await useCase.execute({ method: 'GET', pathname: '/settings' });
    expect(calls).toEqual(['shell']);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe('OK');
    expect(res.headers.get('X-Frame-Options')).toBe('SAMEORIGIN');
    expect(res.headers.get('Cache-Control')).toBe('public, max-age=3600');
  });

  it('preserves multi-value headers through decoration (Set-Cookie multiplicity)', async () => {
    // headerSnapshot (forEach) is multiplicity-blind, so this pin reads
    // the Set-Cookie list directly: both upstream values must survive
    // the new Headers(...) copy -> set -> rebuild path.
    const upstreamHeaders = new Headers();
    upstreamHeaders.append('Set-Cookie', 'a=1');
    upstreamHeaders.append('Set-Cookie', 'b=2');
    upstreamHeaders.set('Content-Type', 'text/html');
    const { fetcher, calls } = makeFetcher(
      () => new Response('OK', { status: 200, headers: upstreamHeaders }),
    );
    const useCase = makeUseCase(fetcher);
    const res = await useCase.execute({ method: 'GET', pathname: '/main.wasm' });
    expect(calls).toEqual(['original']);
    expect(res.headers.getSetCookie()).toEqual(['a=1', 'b=2']);
    expect(res.headers.get('Cache-Control')).toBe(
      'public, max-age=31536000, immutable',
    );
  });

  it('supports sequential reuse: one instance, independent results', async () => {
    // Statelessness pin: the same instance serves a fallback, an
    // immutable asset, and an upstream error back-to-back with no
    // cross-talk.
    let upstreamCall = 0;
    const responses = [
      new Response('shell', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      new Response('missing', { status: 404, headers: UPSTREAM_ERROR_HEADERS }),
    ];
    const { fetcher, calls } = makeFetcher(() => {
      const response = responses[upstreamCall];
      if (!response) {
        throw new Error('unexpected extra upstream call');
      }
      upstreamCall += 1;
      return response;
    });
    const useCase = makeUseCase(fetcher);
    const first = await useCase.execute({ method: 'GET', pathname: '/settings' });
    const second = await useCase.execute({ method: 'GET', pathname: '/main.wasm' });
    const third = await useCase.execute({ method: 'GET', pathname: '/x.css' });
    expect(calls).toEqual(['shell', 'original', 'original']);
    expect(first.headers.get('Cache-Control')).toBe(HOURLY);
    expect(second.headers.get('Cache-Control')).toBe(IMMUTABLE);
    expect(third.status).toBe(404);
  });
});
