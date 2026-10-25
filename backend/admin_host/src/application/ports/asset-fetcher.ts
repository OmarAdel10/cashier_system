/**
 * Port: fetches an asset by URL pathname.
 *
 * The application layer depends on this interface instead of the
 * Cloudflare Workers ASSETS binding, so use cases stay testable
 * against a mock and the runtime adapter will be swappable (the
 * wiring phases of this series will introduce it; the canonical
 * plan lives in the phase-series refactor plan and
 * docs/followups.md wiring obligations).
 *
 * Contract: `pathname` is a URL pathname only — the value of
 * `new URL(request.url).pathname`: always starts with `/` and MAY
 * begin with `//` (a protocol-relative-URL hazard — treat it as
 * opaque path data, never as URL authority, per the adapter
 * obligations below); no query string, no fragment, no full URL.
 * An adapter MUST NOT rebuild the request URL from the pathname on
 * the asset branch — a `//`-prefixed pathname resolves as a
 * protocol-relative URL against a foreign host.
 *
 * Adapter obligations (the legacy handler's transport fidelity —
 * `src/index.ts`, pinned by `test/domain-parity.test.ts`):
 * - Pass the pathname byte-for-byte: no decoding, no normalization.
 *   The assets binding is expected to decode percent-encoded
 *   pathnames itself (unverified — see docs/followups.md,
 *   DAFTARI-146), and the worker's classification must see the
 *   raw encoded form.
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
