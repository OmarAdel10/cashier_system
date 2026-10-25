/**
 * Port: fetches an asset by URL pathname.
 *
 * The application layer depends on this interface instead of the
 * Cloudflare Workers ASSETS binding, so use cases stay testable
 * against a mock and the runtime adapter is swappable
 * (see `infrastructure/adapters/`, wiring phase of this series).
 *
 * Contract: `pathname` is a URL pathname only — the value of
 * `new URL(request.url).pathname`: exactly one leading `/`, no
 * query string, no fragment, no full URL. An adapter MUST NOT
 * rebuild the request URL from the pathname on the asset branch —
 * a `//`-prefixed pathname resolves as a protocol-relative URL
 * against a foreign host.
 *
 * Adapter obligations (the legacy handler's transport fidelity —
 * `src/index.ts`, pinned by `test/domain-parity.test.ts`):
 * - Pass the pathname byte-for-byte: no decoding, no normalization.
 *   The assets binding decodes percent-encoded pathnames itself, and
 *   the worker's classification must see the raw encoded form.
 * - SPA-fallback shell fetch ONLY: rebuild the request URL with
 *   `new URL('/index.html', request.url)` — never string
 *   concatenation. The shell path is a constant, so reconstruction
 *   is safe there and only there.
 * - Asset branch: forward the ORIGINAL request verbatim — same
 *   host, path, and query (legacy `src/index.ts` passes the request
 *   object through untouched). NEVER reconstruct the asset URL from
 *   the pathname; it carries the attacker-influenced raw path.
 * - Preserve the ORIGINAL request's transport context on both
 *   branches: method, all request headers (e.g. Accept,
 *   If-None-Match), and body.
 * - Honor the query contract: the SPA-fallback branch strips the
 *   query (the use case asks for `/index.html`), the asset branch
 *   forwards it (the original query rides the original request).
 *   See docs/followups.md (wiring obligations) — that entry is the
 *   canonical list for the wiring step that deletes the canary.
 */
export interface AssetFetcher {
  /** Fetch the asset at `pathname` and return the upstream response. */
  fetch(pathname: string): Promise<Response>;
}
