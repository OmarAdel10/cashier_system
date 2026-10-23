import { describe, expect, it } from 'vitest';
import { StaticAssetClassifierImpl } from '../services/static-asset-classifier.impl';

describe('StaticAssetClassifierImpl', () => {
  const clf = new StaticAssetClassifierImpl();

  describe('isStaticAssetPath', () => {
    it.each([
      ['/main.wasm', true, 'path with an extension'],
      ['/assets/app.js', true, 'assets dir with extension'],
      ['/assets/no-extension', true, 'assets dir prefix without extension'],
      ['/a.b/main', true, 'dot inside a directory segment still classifies static'],
      ['.', true, 'lone dot'],
      ['..', true, 'double dot'],
      ['main.js', true, 'dot without leading slash'],
      ['/', false, 'spa root'],
      ['/settings', false, 'spa route'],
      ['/users/42/profile', false, 'nested route without dot'],
      ['/ASSETS/x', false, 'assets prefix is case-sensitive'],
      ['/foo/assets/bar', false, 'assets prefix only matches at the start'],
      ['', false, 'empty pathname'],
    ])('classifies %s as static=%s (%s)', (pathname, expected) => {
      expect(clf.isStaticAssetPath(pathname)).toBe(expected);
    });
  });

  describe('extOf', () => {
    it.each([
      ['.wasm', '/main.wasm'],
      ['.css', '/a/b/c.CSS'],
      ['.', '/file.'],
      ['', '/settings'],
      ['', '/'],
    ])('extracts %s from %s', (expected, pathname) => {
      expect(clf.extOf(pathname)).toBe(expected);
    });

    it('returns the last-dot suffix even when the dot sits in a directory segment (legacy behavior)', () => {
      // Preserved verbatim from the legacy handler: extOf never inspects
      // segments, so '/a.b/main' yields '.b/main' — not immutable, thus
      // served hourly. Behavior preservation beats beauty in a refactor.
      expect(clf.extOf('/a.b/main')).toBe('.b/main');
    });
  });
});
