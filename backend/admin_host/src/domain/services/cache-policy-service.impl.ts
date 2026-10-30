/**
 * Default implementation of CachePolicyService.
 *
 * Extension extraction is delegated to StaticAssetClassifier — the
 * classifier owns `extOf`, so the extension quirk (last-dot suffix) has a
 * single source of truth in the domain.
 *
 * Hardened per DAFTARI-134/135:
 * - Immutable year-long cache only for fingerprinted assets (hash in filename)
 *   (DAFTARI-134). Non-fingerprinted immutable-ext assets fall back to hourly.
 * - SPA shell (`/`, `/index.html`) gets `max-age=0, must-revalidate`
 *   instead of hourly (DAFTARI-135).
 * - Error responses (>= 400) get `max-age=0, must-revalidate` without `public`
 *   (DAFTARI-135) — applied at the use-case layer.
 */
import type { CachePolicyService } from './cache-policy-service';
import type { StaticAssetClassifier } from './static-asset-classifier';

const CACHE_ONE_HOUR = 'public, max-age=3600';
const CACHE_IMMUTABLE = 'public, max-age=31536000, immutable';
const CACHE_SPA_SHELL = 'max-age=0, must-revalidate';
const CACHE_ERROR = 'max-age=0, must-revalidate';

const IMMUTABLE_EXTS = new Set<string>([
  '.wasm', '.js', '.mjs', '.css', '.woff2', '.ttf',
]);

// Fingerprinted asset: filename contains a hex hash (8+ chars) before the
// extension, e.g. main.a1b2c3d4.js, runtime.abc123def.css
const FINGERPRINT_HASH = /[0-9a-f]{8,}\.[a-z0-9]+$/i;

export class CachePolicyServiceImpl implements CachePolicyService {
  private readonly classifier: StaticAssetClassifier;

  constructor(classifier: StaticAssetClassifier) {
    this.classifier = classifier;
  }

  cacheControlFor(pathname: string): string {
    // SPA shell: short-lived, must-revalidate — never cached long-term.
    if (pathname === '/' || pathname === '/index.html') {
      return CACHE_SPA_SHELL;
    }
    const ext = this.classifier.extOf(pathname);
    if (IMMUTABLE_EXTS.has(ext) && FINGERPRINT_HASH.test(pathname)) {
      return CACHE_IMMUTABLE;
    }
    return CACHE_ONE_HOUR;
  }

  cacheControlForError(): string {
    return CACHE_ERROR;
  }
}
