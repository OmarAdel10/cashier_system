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

function makeFetcher(upstream: (pathname: string) => Response): {
  fetcher: AssetFetcher;
  calls: string[];
} {
  const calls: string[] = [];
  const fetcher: AssetFetcher = {
    fetch: async (pathname: string) => {
      calls.push(pathname);
      return upstream(pathname);
    },
  };
  return { fetcher, calls };
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
    expect(calls).toEqual(['/index.html']);
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
      expect(calls).toEqual(['/index.html']);
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
    expect(calls).toEqual(['/main.wasm']);
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
      const { fetcher, calls } = makeFetcher(
        () =>
          new Response('missing', {
            status,
            statusText: 'Upstream error',
            headers: UPSTREAM_ERROR_HEADERS,
          }),
      );
      const useCase = makeUseCase(fetcher);
      const res = await useCase.execute({ method: 'GET', pathname });
      expect(calls).toEqual([pathname]);
      expect(res.status).toBe(status);
      expect(res.statusText).toBe('Upstream error');
      expect(await res.text()).toBe('missing');
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
    for (const status of [200, 404, 500]) {
      const { fetcher } = makeFetcher(
        () => new Response('shell', { status, headers: UPSTREAM_OK_HEADERS }),
      );
      const useCase = makeUseCase(fetcher);
      const res = await useCase.execute({
        method: 'GET',
        pathname: '/settings',
      });
      expect(res.status).toBe(status);
      expect(await res.text()).toBe('shell');
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
    ];
    for (const [method, pathname, cache] of methodRows) {
      const { fetcher, calls } = makeFetcher(
        () => new Response('OK', { status: 200, headers: UPSTREAM_OK_HEADERS }),
      );
      const useCase = makeUseCase(fetcher);
      const res = await useCase.execute({ method, pathname });
      expect(calls).toEqual([pathname]);
      expect(res.status).toBe(200);
      expect(res.headers.get('Cache-Control')).toBe(cache);
      expect(headerSnapshot(res.headers)).toEqual(decoratedExpected(cache));
    }
  });

  it('returns non-GET asset-branch errors untouched', async () => {
    const { fetcher, calls } = makeFetcher(
      () =>
        new Response('missing', {
          status: 404,
          headers: UPSTREAM_ERROR_HEADERS,
        }),
    );
    const useCase = makeUseCase(fetcher);
    const res = await useCase.execute({
      method: 'POST',
      pathname: '/settings',
    });
    expect(calls).toEqual(['/settings']);
    expect(res.status).toBe(404);
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
    expect(calls).toEqual(['/index.html']);
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
  });

  it('propagates upstream fetch rejections on the fallback branch', async () => {
    const fetcher: AssetFetcher = {
      fetch: async () => {
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
      fetch: async () => {
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
});
