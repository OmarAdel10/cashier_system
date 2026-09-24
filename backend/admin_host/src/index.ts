/**
 * daftari-admin — Workers Static Assets host for the admin dashboard's
 * Flutter WASM build output.
 *
 * Upload `dist/`, `index.html`, `main.dart.wasm`/etc. via wrangler (see
 * wrangler.toml `assets.directory`). Each asset is served with safe headers
 * (immutable cache for version-locked filenames, 1-hour for index.html).
 * Static host for the admin dashboard's Flutter WASM build. No service bindings yet.
 */
const CACHE_ONE_HOUR = 'public, max-age=3600';
const CACHE_IMMUTABLE = 'public, max-age=31536000, immutable';

const IMMUTABLE_EXTS = new Set<string>([
  '.wasm', '.js', '.mjs', '.css', '.woff2', '.ttf',
]);

export interface AssetBindings {
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
  // Cross-origin isolation — required for Flutter WASM (SharedArrayBuffer).
  headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
  headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  // Security headers mirroring landing_page/web/_headers.
  headers.set('X-Frame-Options', 'DENY');
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  headers.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  headers.set('Strict-Transport-Security', 'max-age=63072000; includeSubDomains; preload');
  headers.set(
    'Content-Security-Policy',
    "default-src 'self'; object-src 'none'; base-uri 'self'; " +
      "script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; " +
      "font-src 'self' data:; img-src 'self' data:; " +
      "connect-src 'self' https://*.daftariapp.workers.dev wss://*.daftariapp.workers.dev " +
      'https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com; ' +
      "frame-ancestors 'none'",
  );
  return new Response(res.body, {
    status: res.status,
    statusText: res.statusText,
    headers,
  });
}
