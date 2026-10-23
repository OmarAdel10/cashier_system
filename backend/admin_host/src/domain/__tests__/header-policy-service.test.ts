import { describe, expect, it } from 'vitest';
import { HeaderPolicyServiceImpl } from '../services/header-policy-service.impl';

/**
 * Verbatim security-header map copied from the legacy fetch handler.
 * Changing any value here is a policy change and must be reviewed
 * against the Firebase popup-auth + Skwasm constraints (COOP/COEP).
 */
const EXPECTED_HEADERS: Record<string, string> = {
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

describe('HeaderPolicyServiceImpl', () => {
  const svc = new HeaderPolicyServiceImpl();

  it('returns the full security-header map for the handler to apply as overrides', () => {
    expect(svc.securityHeaders()).toEqual(EXPECTED_HEADERS);
  });

  it('exposes exactly 8 security headers', () => {
    expect(Object.keys(svc.securityHeaders())).toHaveLength(8);
  });

  it('returns a fresh map on every call (callers may mutate copies)', () => {
    const first = svc.securityHeaders();
    const second = svc.securityHeaders();
    expect(second).not.toBe(first);
    first['X-Frame-Options'] = 'MUTATED';
    expect(svc.securityHeaders()['X-Frame-Options']).toBe('DENY');
  });
});
