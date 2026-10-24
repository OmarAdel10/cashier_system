/**
 * Default implementation of StaticAssetClassifier.
 *
 * Behavior copied verbatim from the legacy fetch handler so the refactor
 * is a pure extraction with zero observable change.
 */
import type { StaticAssetClassifier } from './static-asset-classifier';

export class StaticAssetClassifierImpl implements StaticAssetClassifier {
  isStaticAssetPath(pathname: string): boolean {
    return pathname.includes('.') || pathname.startsWith('/assets/');
  }

  extOf(pathname: string): string {
    const last = pathname.lastIndexOf('.');
    return last === -1 ? '' : pathname.slice(last).toLowerCase();
  }
}
