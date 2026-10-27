import { describe, expect, it } from 'vitest';

import { createAdminHostAppFromEnv } from './runtime';
import type { AssetBindings } from './infrastructure/adapters/workers-asset-fetcher';

const HOURLY = 'public, max-age=3600';
const X_FRAME_OPTIONS = 'DENY';

/**
 * Runtime entry pins: fail-closed env validation (a missing or malformed
 * ASSETS binding must throw before any request is served — a worker
 * deployed without its binding fails loudly at first use, never serves
 * unauthenticated 500s silently) + the full production-path smoke:
 * real adapter → real factory composition → real use case → real domain
 * services over a mocked binding, asserting the observable shell behavior.
 */

function makeEnv(): { env: AssetBindings; requestedUrls: string[] } {
  const requestedUrls: string[] = [];
  const env: AssetBindings = {
    ASSETS: {
      fetch: async (request: Request) => {
        requestedUrls.push(request.url);
        return new Response('shell-body', {
          status: 200,
          headers: { 'Content-Type': 'text/html' },
        });
      },
    },
    ENVIRONMENT: 'test',
  };
  return { env, requestedUrls };
}

describe('createAdminHostAppFromEnv (fail-closed env validation)', () => {
  it('throws when the ASSETS binding is missing', () => {
    expect(() => createAdminHostAppFromEnv({} as AssetBindings)).toThrow(
      'Missing required binding: ASSETS',
    );
  });

  it('throws when ASSETS.fetch is not a function', () => {
    expect(() =>
      createAdminHostAppFromEnv({ ASSETS: {} } as unknown as AssetBindings),
    ).toThrow('Missing required binding: ASSETS');
    expect(() =>
      createAdminHostAppFromEnv(undefined as unknown as AssetBindings),
    ).toThrow('Missing required binding: ASSETS');
  });

  it('serves the SPA shell through the full production path when the env is valid', async () => {
    const { env, requestedUrls } = makeEnv();
    const app = createAdminHostAppFromEnv(env);
    const res = await app.fetch(new Request('https://admin.example/settings'));
    expect(requestedUrls).toEqual(['https://admin.example/index.html']);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe('shell-body');
    expect(res.headers.get('Cache-Control')).toBe(HOURLY);
    expect(res.headers.get('X-Frame-Options')).toBe(X_FRAME_OPTIONS);
  });
});

describe('runtime default export (wrangler entry)', () => {
  it('serves requests through the composed app', async () => {
    const { env, requestedUrls } = makeEnv();
    const mod = await import('./runtime');
    const handler = mod.default as {
      fetch: (request: Request, env: AssetBindings) => Promise<Response>;
    };
    const res = await handler.fetch(
      new Request('https://admin.example/settings'),
      env,
    );
    expect(res.status).toBe(200);
    expect(requestedUrls).toEqual(['https://admin.example/index.html']);
  });

  it('propagates the fail-closed validation error', async () => {
    const mod = await import('./runtime');
    const handler = mod.default as {
      fetch: (request: Request, env: AssetBindings) => Promise<Response>;
    };
    await expect(
      handler.fetch(new Request('https://admin.example/settings'), {
        ASSETS: undefined,
      } as unknown as AssetBindings),
    ).rejects.toThrow('Missing required binding: ASSETS');
  });
});
