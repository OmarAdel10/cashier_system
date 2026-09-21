import { describe, expect, it, vi } from 'vitest';

vi.mock('@libsql/client', () => ({
  createClient: () => ({ execute: async () => ({ rows: [], columns: [], rowsAffected: 0 }) }),
}));

import worker from '../src/index';
import type { AssetBindings } from '../src/index';

const assetResponse = vi.fn(async (_req: Request, _init: () => ResponseHeaders) => {
  return new Response('OK', {
    status: 200,
    headers: { 'Content-Type': 'application/javascript' },
  });
});

const env: AssetBindings = {
  ASSETS: { fetch: async (_req: Request) => assetResponse(_req, () => new ResponseHeaders()) },
  ENVIRONMENT: 'test',
};

function getHeaders(h: Headers): Record<string, string> {
  const out: Record<string, string> = {};
  h.forEach((v, k) => { out[k] = v; });
  return out;
}

describe('admin host fetch handler', () => {
  it('serves wasm asset with immutable + COOP/COEP headers', async () => {
    assetResponse.mockResolvedValueOnce(new Response('BYTES', {
      status: 200,
      headers: { 'Content-Type': 'application/wasm' },
    }));
    const res = await worker.fetch(
      new Request('https://admin.example/main.wasm'),
      env,
      {} as unknown,
    );
    expect(res.headers.get('Cache-Control')).toContain('immutable');
    expect(res.headers.get('Cross-Origin-Embedder-Policy')).toBe('require-corp');
  });

  it('SPA fallback: any non-asset path returns index.html', async () => {
    assetResponse.mockResolvedValueOnce(new Response('INDEX', { status: 200 }));
    const res = await worker.fetch(
      new Request('https://admin.example/settings'),
      env,
      {} as unknown,
    );
    expect(res.status).toBe(200);
    expect(res.headers.get('Cache-Control')).toContain('3600');
  });
});
