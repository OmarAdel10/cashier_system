/**
 * Default implementation of HeaderPolicyService.
 *
 * Values copied verbatim from the legacy fetch handler (which mirrored
 * landing_page/web/_headers). Rationale lives in the interface docs and
 * the domain README.
 */
import type { HeaderPolicyService } from './header-policy-service';

export class HeaderPolicyServiceImpl implements HeaderPolicyService {
  securityHeaders(): Record<string, string> {
    return {
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cross-Origin-Opener-Policy': 'same-origin-allow-popups',
      'X-Frame-Options': 'DENY',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'strict-origin-when-cross-origin',
      'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
      'Strict-Transport-Security': 'max-age=63072000; includeSubDomains; preload',
      'Content-Security-Policy':
        "default-src 'self'; object-src 'none'; base-uri 'self'; " +
        "script-src 'self' 'wasm-unsafe-eval' https://apis.google.com; " +
        "style-src 'self' 'unsafe-inline'; " +
        "font-src 'self' data:; img-src 'self' data:; " +
        "connect-src 'self' https://*.daftariapp.workers.dev wss://*.daftariapp.workers.dev " +
        'https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com; ' +
        "frame-src 'self' https://*.firebaseapp.com; " +
        "frame-ancestors 'none'",
    };
  }
}
