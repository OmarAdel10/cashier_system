import { describe, expect, it, vi } from 'vitest';

import { createAdminHostApp } from '../admin-host-app';
import type { AdminHostAppDeps } from '../admin-host-app';
import type { AssetFetcher } from '../../../application/ports/asset-fetcher';

/**
 * Factory pins: createAdminHostApp is the composition-root handler —
 * per request it builds the use case from the injected deps (a fresh
 * fetcher per request from fetcherFactory, the shared policy services),
 * parses the presentation inputs, and delegates. No policy logic lives
 * here; marker stubs prove every decision routes through the injected
 * collaborators, never hidden defaults.
 */

function makeDeps(): {
  deps: AdminHostAppDeps;
  fetcherFactory: ReturnType<typeof vi.fn>;
  calls: string[];
} {
  const calls: string[] = [];
  const fakeFetcher: AssetFetcher = {
    fetchShell: vi.fn(async () => {
      calls.push('shell');
      return new Response('OK', { status: 200 });
    }),
    forwardOriginal: vi.fn(async () => {
      calls.push('original');
      return new Response('OK', { status: 200 });
    }),
  };
  const fetcherFactory = vi.fn((request: Request) => {
    calls.push(`factory:${request.url}`);
    return fakeFetcher;
  });
  const deps: AdminHostAppDeps = {
    fetcherFactory,
    cachePolicy: { cacheControlFor: () => 'stub-cache-directive' },
    headerPolicy: { securityHeaders: () => ({ 'X-Stub-Header': 'stub' }) },
    classifier: { isStaticAssetPath: () => false, extOf: () => '' },
  };
  return { deps, fetcherFactory, calls };
}

describe('createAdminHostApp (composition-root handler)', () => {
  it('builds a fresh fetcher per request and passes the request itself', async () => {
    const { deps, fetcherFactory, calls } = makeDeps();
    const app = createAdminHostApp(deps);
    const request = new Request('https://admin.example/settings');
    await app.fetch(request);
    expect(fetcherFactory).toHaveBeenCalledTimes(1);
    expect(fetcherFactory).toHaveBeenCalledWith(request);
    expect(calls).toContain('factory:https://admin.example/settings');
  });

  it('routes decisions through the injected stubs, never hidden defaults', async () => {
    const { deps, calls } = makeDeps();
    const app = createAdminHostApp(deps);
    const res = await app.fetch(new Request('https://admin.example/settings'));
    expect(calls).toEqual(['factory:https://admin.example/settings', 'shell']);
    expect(res.headers.get('X-Stub-Header')).toBe('stub');
    expect(res.headers.get('Cache-Control')).toBe('stub-cache-directive');
  });

  it('parses the URL pathname only — the classifier never sees the query', async () => {
    const seen: string[] = [];
    const { deps } = makeDeps();
    deps.classifier = {
      isStaticAssetPath: (pathname: string) => {
        seen.push(pathname);
        return false;
      },
      extOf: () => '',
    };
    const app = createAdminHostApp(deps);
    await app.fetch(new Request('https://admin.example/settings?x=1'));
    expect(seen).toEqual(['/settings']);
  });

  it('takes the asset branch for non-GET methods', async () => {
    const { deps, calls } = makeDeps();
    const app = createAdminHostApp(deps);
    await app.fetch(
      new Request('https://admin.example/settings', { method: 'POST' }),
    );
    expect(calls).toEqual(['factory:https://admin.example/settings', 'original']);
  });

  it('creates a new fetcher for each sequential request', async () => {
    const { deps, fetcherFactory } = makeDeps();
    const app = createAdminHostApp(deps);
    await app.fetch(new Request('https://admin.example/settings'));
    await app.fetch(new Request('https://admin.example/main.wasm'));
    expect(fetcherFactory).toHaveBeenCalledTimes(2);
  });

  it('propagates a throwing fetcherFactory — no hidden catch, no synthesized response', async () => {
    const { deps } = makeDeps();
    deps.fetcherFactory = () => {
      throw new Error('factory broke');
    };
    const app = createAdminHostApp(deps);
    await expect(
      app.fetch(new Request('https://admin.example/settings')),
    ).rejects.toThrow('factory broke');
  });
});
