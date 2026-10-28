/**
 * Domain service for the admin host's security-header policy.
 *
 * Owns the exact set of security headers the host applies to the
 * responses it decorates. Values are policy: changing one is a security
 * decision, not a code cleanup.
 */
export interface HeaderPolicyService {
  /**
   * Returns the full security-header map. Each call returns a fresh copy;
   * callers may mutate the result without affecting later calls.
   *
   * These headers are overrides set onto a copy of the upstream
   * response's headers, never a wholesale replacement — upstream
   * headers such as `Content-Type` and `ETag` survive, and
   * `Cache-Control` comes from `CachePolicyService`.
   *
   * Legacy behavior (to preserve or change deliberately at the wiring
   * step): asset responses with status >= 400 are returned untouched,
   * without these headers; SPA-fallback responses carry them regardless
   * of status. Recommended wiring default for a static host: apply the
   * headers to every response, including >= 400.
   *
   * Policy highlights:
   * - COEP `require-corp` + COOP `same-origin-allow-popups`: Firebase
   *   `signInWithPopup` returns its credential via `window.opener`, which
   *   strict `same-origin` severs. Consequence:
   *   `window.crossOriginIsolated` is false, so Skwasm runs
   *   single-threaded. The allow-popups direction also retains the opener
   *   handle when the dashboard itself is opened as a popup (reverse
   *   tabnabbing): consumers must open outbound links with `noopener`;
   *   `signInWithRedirect` is the long-term alternative.
   * - CSP allows `wasm-unsafe-eval`, `https://apis.google.com` (gapi
   *   loader), the Firebase iframe hub, and the daftari Workers backends.
   *
   * @returns fresh `Record<string, string>` of header name → value
   */
  securityHeaders(): Record<string, string>;
}
