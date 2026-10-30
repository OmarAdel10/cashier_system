import { describe, expect, it } from 'vitest';
import { StaticAssetClassifierImpl } from '../services/static-asset-classifier.impl';

describe('StaticAssetClassifierImpl', () => {
  const clf = new StaticAssetClassifierImpl();

  describe('isStaticAssetPath', () => {
    it.each([
      ['/main.wasm', true, 'fingerprinted wasm asset'],
      ['/assets/app.js', true, 'assets dir with extension'],
      ['/assets/no-extension', false, 'assets dir prefix without extension'],
      ['/a.b/main', false, 'dot in dir segment — last segment has no dot (DAFTARI-141)'],
      ['.', false, 'lone dot — ext not in allowlist'],
      ['..', false, 'double dot — traversal guard (DAFTARI-146)'],
      ['main.js', true, 'dot without leading slash'],
      ['/', false, 'spa root'],
      ['/settings', false, 'spa route'],
      ['/users/42/profile', false, 'nested route without dot'],
      ['/ASSETS/x', false, 'assets prefix is case-sensitive'],
      ['/foo/assets/bar', false, 'assets prefix only matches at the start'],
      ['/assets', false, 'assets dir without trailing slash'],
      ['/assets/', false, 'bare assets dir'],
      ['/a%2Eb', false, 'encoded dot decodes to /a.b — ext .b not allowlisted (DAFTARI-146)'],
      ['/settings?x=1.2', false, 'query string not part of extension (pathname-only contract)'],
      ['/main.wasm?v=2', false, 'query string not part of extension'],
      ['', false, 'empty pathname'],
      ['/.env', false, 'dotfile rejected (DAFTARI-145)'],
      ['/config/.secret', false, 'dotfile in subdirectory rejected (DAFTARI-145)'],
      ['/../etc/passwd', false, 'traversal segment rejected (DAFTARI-146)'],
      ['/main.a1b2c3d4.js', true, 'fingerprinted js asset'],
      ['/style.abc123.css', true, 'fingerprinted css asset'],
      ['/image.png', true, 'png asset'],
      ['/font.woff2', true, 'woff2 asset'],
      ['/doc.pdf', true, 'pdf asset'],
      ['/data.json', true, 'json asset'],
      ['/script.jsx', false, 'jsx not in allowlist'],
      ['/page.xhtml', false, 'xhtml not in allowlist'],
    ])('classifies %s as static=%s (%s)', (pathname, expected) => {
      expect(clf.isStaticAssetPath(pathname)).toBe(expected);
    });
  });

  describe('extOf', () => {
    it.each([
      ['.wasm', '/main.wasm'],
      ['.wasm', '/main.dart.wasm'],
      ['.css', '/a/b/c.CSS'],
      ['.wåsm', '/x.WÅSM'],
      ['.', '/file.'],
      ['.', '.'],
      ['.', '.'],
      ['.wasm', '.wasm'],
      ['.hidden', '/.hidden'],
      ['', '/settings'],
      ['', '/'],
      ['', ''],
      ['', '/a%2Eb'],
      ['.wasm?v=2', '/main.wasm?v=2'],
    ])('extracts %s from %s', (expected, pathname) => {
      expect(clf.extOf(pathname)).toBe(expected);
    });

    it('returns the last-dot suffix even when the dot sits in a directory segment', () => {
      expect(clf.extOf('/a.b/main')).toBe('.b/main');
    });
  });

  describe('ignore patterns (.assetsignore)', () => {
    const clfWithIgnore = new StaticAssetClassifierImpl(['^\\.env$', '^/private/']);

    it('rejects paths matching ignore patterns (DAFTARI-145)', () => {
      expect(clfWithIgnore.isStaticAssetPath('/.env')).toBe(false);
      expect(clfWithIgnore.isStaticAssetPath('/private/config.json')).toBe(false);
    });

    it('allows paths not matching ignore patterns', () => {
      expect(clfWithIgnore.isStaticAssetPath('/public/config.json')).toBe(true);
    });
  });
});
