import { describe, expect, it, vi } from 'vitest';

import worker from '../src/index';
import type { AssetBindings } from '../src/index';

const assetResponse = vi.fn(async (_req: Request, _init: () => Response) => {
  return new Response('OK', {
    status: 200,
    headers: { 'Content-Type': 'application/javascript' },
  });
});

const env: AssetBindings = {
  ASSETS: { fetch: async (_req: Request) => assetResponse(_req, () => new Response()) },
  ENVIRONMENT: 'test',
};

function getHeaders(h: Headers): Record<string, string> {
  const out: Record<string, string> = {};
  h.forEach((v, k) => { out[k] = v; });
  return out;
}

describe('admin host fetch handler', () => {
  it('serves fingerprinted wasm asset with immutable + COOP/COEP headers', async () => {
    assetResponse.mockResolvedValueOnce(new Response('BYTES', {
      status: 200,
      headers: { 'Content-Type': 'application/wasm' },
    }));
    const res = await worker.fetch(
      new Request('https://admin.example/main.a1b2c3d4.wasm'),
      env,
    );
    expect(res.headers.get('Cache-Control')).toContain('immutable');
    expect(res.headers.get('Cross-Origin-Embedder-Policy')).toBe('require-corp');
  });

  it('SPA fallback: any non-asset path returns index.html with SPA_SHELL cache', async () => {
    assetResponse.mockResolvedValueOnce(new Response('INDEX', { status: 200 }));
    const res = await worker.fetch(
      new Request('https://admin.example/settings'),
      env,
    );
    expect(res.status).toBe(200);
    expect(res.headers.get('Cache-Control')).toBe('max-age=0, must-revalidate');
  });

  it('sets hardened security headers on all responses', async () => {
    assetResponse.mockResolvedValueOnce(new Response('ASSET', {
      status: 200,
      headers: { 'Content-Type': 'application/javascript' },
    }));
    const res = await worker.fetch(
      new Request('https://admin.example/assets/app.a1b2c3d4.js'),
      env,
    );
    expect(res.headers.get('X-Frame-Options')).toBe('DENY');
    expect(res.headers.get('X-Content-Type-Options')).toBe('nosniff');
    expect(res.headers.get('Referrer-Policy')).toBe('strict-origin-when-cross-origin');
    expect(res.headers.get('Permissions-Policy')).toContain('camera=()');
    expect(res.headers.get('Permissions-Policy')).toContain('payment=()');
    expect(res.headers.get('Strict-Transport-Security')).toBe('max-age=63072000; includeSubDomains');
    expect(res.headers.get('Strict-Transport-Security')).not.toContain('preload');
    expect(res.headers.get('Cross-Origin-Opener-Policy')).toBe('same-origin-allow-popups');
    expect(res.headers.get('Cross-Origin-Embedder-Policy')).toBe('require-corp');
    const csp = res.headers.get('Content-Security-Policy');
    expect(csp).toContain("script-src 'self' 'wasm-unsafe-eval' 'require-trusted-types-for' 'script'");
    expect(csp).toContain("style-src 'self'");
    expect(csp).not.toContain("'unsafe-inline'");
    expect(csp).toContain("frame-src 'self' https://*.firebaseapp.com");
    expect(csp).toContain('https://daftariapp.workers.dev');
    expect(csp).toContain('wss://daftariapp.workers.dev');
    expect(csp).not.toContain('*.daftariapp.workers.dev');
    expect(csp).toContain("form-action 'self'");
    expect(csp).toContain('report-uri /csp-report');
  });
});
