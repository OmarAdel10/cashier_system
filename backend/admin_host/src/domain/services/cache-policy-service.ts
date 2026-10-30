/**
 * Domain service for static-asset cache policy.
 *
 * Owns the pure decision of which `Cache-Control` directive a pathname
 * deserves: immutable year-long caching for fingerprinted build outputs,
 * one hour for other static assets, `max-age=0, must-revalidate` for the
 * SPA shell, and `max-age=0, must-revalidate` (no `public`) for error
 * responses.
 */
export interface CachePolicyService {
  /**
   * Decides the `Cache-Control` directive for a pathname.
   *
   * @param pathname - URL pathname (no query string)
   * @returns `'public, max-age=31536000, immutable'` for fingerprinted
   *   immutable extensions, `'max-age=0, must-revalidate'` for the SPA
   *   shell, `'public, max-age=3600'` otherwise
   */
  cacheControlFor(pathname: string): string;

  /**
   * Decides the `Cache-Control` directive for error responses (>= 400).
   * Never includes `public` so error responses are not cached by shared
   * caches.
   *
   * @returns `'max-age=0, must-revalidate'`
   */
  cacheControlForError(): string;
}
