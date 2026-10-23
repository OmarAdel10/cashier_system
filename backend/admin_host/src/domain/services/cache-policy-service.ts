/**
 * Domain service for static-asset cache policy.
 *
 * Owns the pure decision of which `Cache-Control` directive a pathname
 * deserves: immutable year-long caching for fingerprinted build outputs
 * (`.wasm`, `.js`, `.mjs`, `.css`, `.woff2`, `.ttf`), one hour for
 * everything else (SPA entry document, manifests, icons).
 */
export interface CachePolicyService {
  /**
   * Decides the `Cache-Control` directive for a pathname.
   *
   * @param pathname - URL pathname (no query string)
   * @returns `'public, max-age=31536000, immutable'` for immutable
   * extensions, `'public, max-age=3600'` otherwise
   */
  cacheControlFor(pathname: string): string;
}
