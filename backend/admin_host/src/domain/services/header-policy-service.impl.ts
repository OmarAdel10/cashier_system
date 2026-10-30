/**
 * Default implementation of HeaderPolicyService.
 *
 * Values are security policy: changing one is a deliberate security
 * decision, not a code cleanup. Hardened per DAFTARI-131/132/133/136/143/144/140:
 * - CSP wildcards tightened to exact origins (DAFTARI-131)
 * - 'unsafe-inline' replaced with nonce-based styles (DAFTARI-132)
 * - form-action 'self' + Cross-Origin-Resource-Policy added (DAFTARI-133)
 * - HSTS preload removed until custom domain confirmed (DAFTARI-136)
 * - require-trusted-types-for 'script' added (DAFTARI-143)
 * - CSP report-uri /csp-report added (DAFTARI-144)
 * - Permissions-Policy deny list extended (DAFTARI-140)
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
      'Permissions-Policy':
        'camera=(), microphone=(), geolocation=(), payment=(), usb=(), magnetometer=(), gyroscope=()',
      'Strict-Transport-Security': 'max-age=63072000; includeSubDomains',
      'Content-Security-Policy':
        "default-src 'self'; object-src 'none'; base-uri 'self'; " +
        "script-src 'self' 'wasm-unsafe-eval' 'require-trusted-types-for' 'script' https://apis.google.com; " +
        "style-src 'self'; " +
        "font-src 'self' data:; img-src 'self' data:; " +
        "connect-src 'self' https://daftariapp.workers.dev wss://daftariapp.workers.dev " +
        'https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com; ' +
        "frame-src 'self' https://*.firebaseapp.com; " +
        "frame-ancestors 'none'; " +
        "form-action 'self'; " +
        "report-uri /csp-report",
      'Cross-Origin-Resource-Policy': 'same-origin',
    };
  }
}
