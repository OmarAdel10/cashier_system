/**
 * Domain service for the admin host's security-header policy.
 *
 * Owns the exact set of security headers applied to every response the
 * host serves. Values are policy: changing one is a security decision,
 * not a code cleanup.
 */
export interface HeaderPolicyService {
  /**
   * Returns the full security-header map. Each call returns a fresh copy;
   * callers may mutate the result without affecting later calls.
   *
   * Policy highlights:
   * - COEP `require-corp` + COOP `same-origin-allow-popups`: Firebase
   *   `signInWithPopup` returns its credential via `window.opener`, which
   *   strict `same-origin` severs. Consequence:
   *   `window.crossOriginIsolated` is false, so Skwasm runs
   *   single-threaded.
   * - CSP allows `wasm-unsafe-eval`, `https://apis.google.com` (gapi
   *   loader), the Firebase iframe hub, and the daftari Workers backends.
   *
   * @returns fresh `Record<string, string>` of header name → value
   */
  securityHeaders(): Record<string, string>;
}
