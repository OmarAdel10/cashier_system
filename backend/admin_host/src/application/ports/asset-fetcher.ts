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
 *
 * Adapter obligations (the legacy handler's transport fidelity —
 * `src/index.ts`, pinned by `test/domain-parity.test.ts`):
 * - Pass the pathname byte-for-byte: no decoding, no normalization.
 *   The assets binding decodes percent-encoded pathnames itself, and
 *   the worker's classification must see the raw encoded form.
 * - Rebuild request URLs with `new URL(pathname, request.url)` —
 *   never string concatenation.
 * - Preserve the ORIGINAL request's transport context: method,
 *   conditional headers (e.g. If-None-Match), and body. The legacy
 *   handler forwards the full original request on the asset branch
 *   and reconstructs it for the SPA-fallback shell fetch.
 * - Honor the query contract: the SPA-fallback branch strips the
 *   query (the use case asks for `/index.html`), the asset branch
 *   forwards it (presentation passes a pathname-only value here;
 *   the original query rides the original request).
 *   See docs/followups.md (wiring obligations) — that entry is the
 *   canonical list for the wiring step that deletes the canary.
 */
export interface AssetFetcher {
  /** Fetch the asset at `pathname` and return the upstream response. */
  fetch(pathname: string): Promise<Response>;
}
