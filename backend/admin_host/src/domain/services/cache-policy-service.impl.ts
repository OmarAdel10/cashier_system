/**
 * Default implementation of CachePolicyService.
 *
 * Extension extraction is delegated to StaticAssetClassifier — the
 * classifier owns `extOf`, so the extension quirk (last-dot suffix) has a
 * single source of truth in the domain.
 */
import type { CachePolicyService } from './cache-policy-service';
import type { StaticAssetClassifier } from './static-asset-classifier';

const CACHE_ONE_HOUR = 'public, max-age=3600';
const CACHE_IMMUTABLE = 'public, max-age=31536000, immutable';

const IMMUTABLE_EXTS = new Set<string>([
  '.wasm', '.js', '.mjs', '.css', '.woff2', '.ttf',
]);

export class CachePolicyServiceImpl implements CachePolicyService {
  private readonly classifier: StaticAssetClassifier;

  constructor(classifier: StaticAssetClassifier) {
    this.classifier = classifier;
  }

  cacheControlFor(pathname: string): string {
    return IMMUTABLE_EXTS.has(this.classifier.extOf(pathname))
      ? CACHE_IMMUTABLE
      : CACHE_ONE_HOUR;
  }
}
