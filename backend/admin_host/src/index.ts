/**
 * daftari-admin — Workers Static Assets host for the admin dashboard's
 * Flutter WASM build output.
 *
 * Upload `dist/`, `index.html`, `main.dart.wasm`/etc. via wrangler (see
 * wrangler.toml `assets.directory`). Each asset is served with safe headers
 * (immutable cache for version-locked filenames, 1-hour for index.html).
 * API calls pass through to daftari-api via service binding.
 */
const CACHE_ONE_HOUR = 'public, max-age=3600';
const CACHE_IMMUTABLE = 'public, max-age=31536000, immutable';

const IMMUTABLE_EXTS = new Set<string>([
  '.wasm', '.js', '.mjs', '.css', '.woff2', '.ttf',
]);

interface AssetBindings {
  ASSETS: {
    fetch: (req: Request) => Promise<Response>;
  };
  ENVIRONMENT: string;
}

export default {
  async fetch(request: Request, env: AssetBindings): Promise<Response> {
    const url = new URL(request.url);
    const pathname = url.pathname;

    // SPA fallback: /settings → /index.html (WASM app reads the path).
    if (
      request.method === 'GET' &&
      (pathname === '/' || !isStaticAssetPath(pathname))
    ) {
      const indexReq = new Request(new URL('/index.html', url), request);
      const res = await env.ASSETS.fetch(indexReq);
      return withHeaders(res, CACHE_ONE_HOUR);
    }

    // Static assets: immutable cache + WASM-safe headers.
    const res = await env.ASSETS.fetch(request);
    if (res.status >= 400) return res;
    return withHeaders(res, IMMUTABLE_EXTS.has(extOf(pathname))
      ? CACHE_IMMUTABLE
      : CACHE_ONE_HOUR);
  },
};

function isStaticAssetPath(pathname: string): boolean {
  return pathname.includes('.') || pathname.startsWith('/assets/');
}

function extOf(pathname: string): string {
  const last = pathname.lastIndexOf('.');
  return last === -1 ? '' : pathname.slice(last).toLowerCase();
}

function withHeaders(res: Response, cacheControl: string): Response {
  const headers = new Headers(res.headers);
  headers.set('Cache-Control', cacheControl);
  headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
  headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  return new Response(res.body, {
    status: res.status,
    statusText: res.statusText,
    headers,
  });
}
