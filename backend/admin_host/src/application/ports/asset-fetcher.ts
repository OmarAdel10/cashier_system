/**
 * Port: fetches an asset by URL pathname.
 *
 * The application layer depends on this interface instead of the
 * Cloudflare Workers ASSETS binding, so use cases stay testable
 * against a mock and the runtime adapter is swappable
 * (see `infrastructure/adapters/`, wiring phase of this series).
 *
 * Contract: `pathname` is a URL pathname only — no query string, no
 * fragment, no full URL. Callers pass `new URL(request.url).pathname`.
 */
export interface AssetFetcher {
  /** Fetch the asset at `pathname` and return the upstream response. */
  fetch(pathname: string): Promise<Response>;
}
