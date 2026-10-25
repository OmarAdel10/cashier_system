/**
 * Port: the two upstream fetches the serve path needs, split by
 * branch.
 *
 * The application layer depends on this interface instead of the
 * Cloudflare Workers ASSETS binding, so use cases stay testable
 * against a mock and the runtime adapter stays swappable (a later
 * wiring phase will introduce it; see docs/followups.md wiring
 * obligations).
 *
 * Why two methods instead of one `fetch(pathname)` (round-4 review):
 * a single pathname-taking fetch could not distinguish the fallback's
 * shell fetch from an asset fetch of the same literal path, and it
 * handed the raw attacker-influenced pathname to the adapter —
 * inviting URL reconstruction, where a `//`-prefixed pathname
 * resolves as a protocol-relative URL against a foreign host. With
 * `fetchShell()` / `forwardOriginal()` both hazards are
 * unrepresentable: no pathname argument exists, and each branch
 * names its own transport.
 *
 * Adapter obligations (the legacy handler's transport fidelity —
 * `src/index.ts`, pinned by `test/domain-parity.test.ts`):
 * - Adapter lifetime: construct the adapter PER REQUEST — an inline
 *   closure or factory over the incoming `request`. NEVER hold the
 *   captured request in module scope or a shared instance: on a
 *   single isolate, a shared adapter lets a later request overwrite
 *   an earlier one's stored request, and the earlier request's
 *   `forwardOriginal()` would forward the later request's
 *   Authorization headers, cookies, or body to the binding. Pin
 *   interleaved-request behavior in the wiring tests.
 * - fetchShell() — SPA-fallback shell fetch ONLY: rebuild the request
 *   as `new Request(new URL('/index.html', request.url), request)`
 *   — any construction keeping the original `request` as the init
 *   object and replacing only the path with the constant
 *   `/index.html` is acceptable; never rebuild from the raw
 *   pathname. The constant shell path replaces the original
 *   path (the query is stripped by the URL rewrite) while the
 *   original method, all request headers (e.g. Accept, If-None-Match),
 *   and body are preserved. This is the ONLY sanctioned URL
 *   reconstruction — the shell path is a compile-time constant.
 * - forwardOriginal() — asset branch: forward the ORIGINAL request
 *   to the binding verbatim — same host, method, full URL including
 *   query, all request headers, and body. NEVER reconstruct a URL
 *   from the command pathname; the binding must see the original
 *   request object, byte-for-byte.
 * - Response fidelity: return the binding's Response verbatim on
 *   both branches — never synthesize statuses, filter headers, or
 *   rewrite the body. A rejected promise is the only sanctioned
 *   failure mode.
 * - Pass the raw path through with no decoding or normalization; the
 *   assets binding is expected to decode percent-encoded pathnames
 *   itself (unverified — see docs/followups.md, DAFTARI-146), and the
 *   worker's classification must see the raw encoded form.
 */
export interface AssetFetcher {
  /**
   * SPA-fallback shell fetch: serve `/index.html` as the shell,
   * preserving the original request's method, headers, and body.
   */
  fetchShell(): Promise<Response>;
  /**
   * Asset branch: forward the original request to the binding
   * verbatim (path, query, host, method, headers, body).
   */
  forwardOriginal(): Promise<Response>;
}
