/**
 * Default implementation of StaticAssetClassifier.
 *
 * Hardened per DAFTARI-141/145/146:
 * - Last-segment + extension-allowlist classification (DAFTARI-141):
 *   only the final path segment is inspected; only allowlisted extensions
 *   classify as static assets. Dot-in-directory-segment paths like
 *   `/a.b/main` no longer classify as static.
 * - `.assetsignore` + dotfile rejection (DAFTARI-145): paths with any
 *   dotfile segment (e.g. `/.env`, `/config/.secret`) are rejected.
 * - URL decoding + traversal guard (DAFTARI-146): pathname is decoded
 *   before classification; `..` segments are rejected.
 */
import type { StaticAssetClassifier } from './static-asset-classifier';

export class StaticAssetClassifierImpl implements StaticAssetClassifier {
  private readonly ignorePatterns: RegExp[];

  // Extension allowlist for static assets — only these extensions classify.
  private static readonly STATIC_EXTS = new Set([
    '.wasm', '.js', '.mjs', '.css', '.html', '.htm', '.json',
    '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico',
    '.woff', '.woff2', '.ttf', '.otf', '.eot',
    '.mp4', '.webm', '.mp3', '.wav', '.pdf',
    '.zip', '.txt', '.xml', '.map',
  ]);

  constructor(ignorePatterns: string[] = []) {
    this.ignorePatterns = ignorePatterns.map((p) => new RegExp(p));
  }

  isStaticAssetPath(pathname: string): boolean {
    // Decode URL-encoded pathname before classification (DAFTARI-146)
    let decoded: string;
    try {
      decoded = decodeURIComponent(pathname);
    } catch {
      return false;
    }

    // Traversal guard: reject `..` segments (DAFTARI-146)
    const segments = decoded.split('/');
    if (segments.includes('..')) {
      return false;
    }

    // Reject dotfiles: any segment starting with '.' (DAFTARI-145)
    for (const segment of segments) {
      if (segment.startsWith('.') && segment.length > 1) {
        return false;
      }
    }

    // Check .assetsignore ignore patterns (DAFTARI-145)
    for (const pattern of this.ignorePatterns) {
      if (pattern.test(decoded)) {
        return false;
      }
    }

    // Last-segment + extension-allowlist classification (DAFTARI-141)
    const lastSegment = segments[segments.length - 1];
    if (!lastSegment || !lastSegment.includes('.')) {
      return false;
    }
    const lastDot = lastSegment.lastIndexOf('.');
    const ext = lastSegment.slice(lastDot).toLowerCase();
    return StaticAssetClassifierImpl.STATIC_EXTS.has(ext);
  }

  extOf(pathname: string): string {
    const last = pathname.lastIndexOf('.');
    return last === -1 ? '' : pathname.slice(last).toLowerCase();
  }
}
