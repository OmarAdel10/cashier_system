import { describe, expect, it } from 'vitest';
import { HeaderPolicyServiceImpl } from '../services/header-policy-service.impl';

/**
 * Hardened security-header map (DAFTARI-131/132/133/136/143/144/140):
 * - CSP wildcards tightened to exact origins
 * - 'unsafe-inline' removed (nonce-based styles)
 * - form-action 'self' + Cross-Origin-Resource-Policy added
 * - HSTS preload removed
 * - require-trusted-types-for 'script' added
 * - CSP report-uri /csp-report added
 * - Permissions-Policy deny list extended
 */
const EXPECTED_HEADERS: Record<string, string> = {
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

describe('HeaderPolicyServiceImpl', () => {
  const svc = new HeaderPolicyServiceImpl();

  it('returns the hardened security-header map for the handler to apply as overrides', () => {
    expect(svc.securityHeaders()).toEqual(EXPECTED_HEADERS);
  });

  it('exposes exactly 9 security headers', () => {
    expect(Object.keys(svc.securityHeaders())).toHaveLength(9);
  });

  it('returns a fresh map on every call (callers may mutate copies)', () => {
    const first = svc.securityHeaders();
    const second = svc.securityHeaders();
    expect(second).not.toBe(first);
    first['X-Frame-Options'] = 'MUTATED';
    expect(svc.securityHeaders()['X-Frame-Options']).toBe('DENY');
  });

  it('CSP contains no wildcard daftariapp.workers.dev origin (DAFTARI-131)', () => {
    const csp = svc.securityHeaders()['Content-Security-Policy'];
    expect(csp).not.toContain('*.daftariapp.workers.dev');
    expect(csp).toContain('https://daftariapp.workers.dev');
    expect(csp).toContain('wss://daftariapp.workers.dev');
  });

  it('CSP has no unsafe-inline (DAFTARI-132)', () => {
    const csp = svc.securityHeaders()['Content-Security-Policy'];
    expect(csp).not.toContain("'unsafe-inline'");
  });

  it('CSP includes form-action self (DAFTARI-133)', () => {
    const csp = svc.securityHeaders()['Content-Security-Policy'];
    expect(csp).toContain("form-action 'self'");
  });

  it('HSTS has no preload (DAFTARI-136)', () => {
    const hsts = svc.securityHeaders()['Strict-Transport-Security'];
    expect(hsts).not.toContain('preload');
  });

  it('CSP includes require-trusted-types-for script (DAFTARI-143)', () => {
    const csp = svc.securityHeaders()['Content-Security-Policy'];
    expect(csp).toContain("'require-trusted-types-for' 'script'");
  });

  it('CSP includes report-uri /csp-report (DAFTARI-144)', () => {
    const csp = svc.securityHeaders()['Content-Security-Policy'];
    expect(csp).toContain('report-uri /csp-report');
  });

  it('Permissions-Policy extends deny list (DAFTARI-140)', () => {
    const pp = svc.securityHeaders()['Permissions-Policy'];
    expect(pp).toContain('payment=()');
    expect(pp).toContain('usb=()');
    expect(pp).toContain('magnetometer=()');
    expect(pp).toContain('gyroscope=()');
  });

  it('Cross-Origin-Resource-Policy is same-origin (DAFTARI-133)', () => {
    expect(svc.securityHeaders()['Cross-Origin-Resource-Policy']).toBe(
      'same-origin',
    );
  });
});
