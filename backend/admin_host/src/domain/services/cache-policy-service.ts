/**
 * Domain service for static-asset cache policy.
 *
 * Owns the pure decision of which `Cache-Control` directive a pathname
 * deserves: immutable year-long caching for fingerprinted build outputs
 * (`.wasm`, `.js`, `.mjs`, `.css`, `.woff2`, `.ttf`), one hour for
 * everything else (SPA entry document, manifests, icons).
 *
 * Known defect preserved verbatim from the legacy handler: the rule
 * matches extensions only, without verifying the filename is actually
 * fingerprinted, and the deploy entry chain (`main.dart.wasm`,
 * `main.dart.js`, `main.dart.mjs`, `flutter.js`,
 * `flutter_service_worker.js`, `flutter_bootstrap.js`,
 * `canvaskit/*`, `fonts/*.ttf`) is stable-named — so deploys do not
 * reach returning users for up to a year. Tracked in
 * `docs/followups.md` (2026-10-23/24, fingerprint enforcement item);
 * the fix belongs to the wiring step, not here.
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
