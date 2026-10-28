/**
 * Domain service for static-asset path classification.
 *
 * Owns the pure decision of whether an incoming pathname should be served
 * as a static asset or fall back to the SPA entry document, and how the
 * file extension is extracted from a pathname.
 */
export interface StaticAssetClassifier {
  /**
   * Decides whether the pathname addresses a static asset.
   *
   * Paths containing a dot anywhere, or living under `/assets/`, are
   * treated as static assets; everything else falls back to the SPA
   * entry document.
   *
   * @param pathname - URL pathname (no query string)
   * @returns true when the pathname is a static asset path
   */
  isStaticAssetPath(pathname: string): boolean;

  /**
   * Extracts the lowercased extension suffix (including the dot) from a
   * pathname, or `''` when the pathname contains no dot.
   *
   * Mirrors the legacy handler: the suffix starts at the LAST dot, even
   * when that dot sits in a directory segment (e.g. `'/a.b/main'` →
   * `'.b/main'`).
   *
   * @param pathname - URL pathname (no query string)
   * @returns lowercased dot-suffix or `''`
   */
  extOf(pathname: string): string;
}
