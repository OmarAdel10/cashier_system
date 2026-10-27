import { describe, expect, it } from 'vitest';

import { WorkersAssetsFetcher } from '../workers-asset-fetcher';

// The binding mock captures the exact request objects it receives so the
// adapter tests can pin transport fidelity (URL, method, headers, body,
// response identity) — the port obligations from
// src/application/ports/asset-fetcher.ts.
function makeEnv() {
  const seenRequests: Request[] = [];
  const upstream = new Response('OK', {
    status: 200,
    headers: { 'Content-Type': 'application/javascript' },
  });
  const env = {
    ASSETS: {
      fetch: async (request: Request) => {
        seenRequests.push(request);
        return upstream;
      },
    },
    ENVIRONMENT: 'test',
  };
  return { env, seenRequests, upstream };
}

describe('WorkersAssetsFetcher (ASSETS binding adapter)', () => {
  it('fetchShell rebuilds only the path: shell URL, query stripped, method + headers preserved', async () => {
    const { env, seenRequests, upstream } = makeEnv();
    const request = new Request('https://admin.example/settings?token=x', {
      headers: { accept: 'text/html,application/xhtml+xml' },
    });
    const fetcher = new WorkersAssetsFetcher(env, request);

    const res = await fetcher.fetchShell();

    // Exactly one binding call, carrying the binding's exact Response
    // back — no rewrap, no memoization, no synthesis.
    expect(seenRequests).toHaveLength(1);
    expect(res).toBe(upstream);
    expect(res.status).toBe(200);

    const forwarded = seenRequests[0];
    if (!forwarded) throw new Error('no request captured');
    expect(forwarded.url).toBe('https://admin.example/index.html');
    expect(forwarded.method).toBe('GET');
    expect(forwarded.headers.get('accept')).toBe(
      'text/html,application/xhtml+xml',
    );
  });

  it('forwardOriginal hands the binding the SAME request object verbatim', async () => {
    const { env, seenRequests, upstream } = makeEnv();
    const request = new Request('https://admin.example/main.wasm?v=2', {
      headers: { 'if-none-match': '"etag-demo"' },
    });
    const fetcher = new WorkersAssetsFetcher(env, request);

    const res = await fetcher.forwardOriginal();

    expect(seenRequests).toHaveLength(1);
    // Identity: the binding receives the original request, not a rebuild.
    expect(seenRequests[0]).toBe(request);
    expect(seenRequests[0]?.url).toBe('https://admin.example/main.wasm?v=2');
    expect(seenRequests[0]?.headers.get('if-none-match')).toBe('"etag-demo"');
    expect(res).toBe(upstream);
  });

  it('forwards a POST body undisturbed through forwardOriginal', async () => {
    const { env, seenRequests } = makeEnv();
    const request = new Request('https://admin.example/settings', {
      method: 'POST',
      body: 'payload data',
    });
    const fetcher = new WorkersAssetsFetcher(env, request);

    await fetcher.forwardOriginal();

    const forwarded = seenRequests[0];
    if (!forwarded) throw new Error('no request captured');
    expect(forwarded.method).toBe('POST');
    // clone() branches the stream: reading the clone proves the body the
    // binding would forward is intact.
    expect(await forwarded.clone().text()).toBe('payload data');
  });

  it('propagates binding rejections verbatim — no wrap, no synthesis, no retry', async () => {
    // Port contract: a rejected promise is the only sanctioned failure
    // mode. A defensive try/catch converting binding failures into a
    // synthesized 500 would break this pin — the adapter must forward
    // the binding's exact rejection and try exactly once.
    const seenRequests: Request[] = [];
    const env = {
      ASSETS: {
        fetch: async (request: Request) => {
          seenRequests.push(request);
          throw new Error('binding down');
        },
      },
      ENVIRONMENT: 'test',
    };
    const request = new Request('https://admin.example/settings');
    const shellFetcher = new WorkersAssetsFetcher(env, request);
    await expect(shellFetcher.fetchShell()).rejects.toThrow('binding down');
    expect(seenRequests).toHaveLength(1);

    const assetFetcher = new WorkersAssetsFetcher(
      env,
      new Request('https://admin.example/main.wasm'),
    );
    await expect(assetFetcher.forwardOriginal()).rejects.toThrow(
      'binding down',
    );
    expect(seenRequests).toHaveLength(2);
  });

  it('holds no shared state: two fetchers over distinct requests each forward their own', async () => {
    const { env, seenRequests } = makeEnv();
    const requestA = new Request('https://admin.example/a.js', {
      headers: { authorization: 'Bearer token-a' },
    });
    const requestB = new Request('https://admin.example/b.js', {
      headers: { authorization: 'Bearer token-b' },
    });

    await new WorkersAssetsFetcher(env, requestA).forwardOriginal();
    await new WorkersAssetsFetcher(env, requestB).forwardOriginal();

    expect(seenRequests).toHaveLength(2);
    expect(seenRequests[0]?.url).toBe('https://admin.example/a.js');
    expect(seenRequests[0]?.headers.get('authorization')).toBe(
      'Bearer token-a',
    );
    expect(seenRequests[1]?.url).toBe('https://admin.example/b.js');
    expect(seenRequests[1]?.headers.get('authorization')).toBe(
      'Bearer token-b',
    );
  });
});
