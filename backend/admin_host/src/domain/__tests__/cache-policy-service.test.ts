import { describe, expect, it } from 'vitest';
import { CachePolicyServiceImpl } from '../services/cache-policy-service.impl';

const IMMUTABLE = 'public, max-age=31536000, immutable';
const HOURLY = 'public, max-age=3600';

describe('CachePolicyServiceImpl', () => {
  const svc = new CachePolicyServiceImpl();

  describe('immutable extensions', () => {
    it.each(['.wasm', '.js', '.mjs', '.css', '.woff2', '.ttf'])(
      'serves %s assets with immutable year-long cache',
      (ext) => {
        expect(svc.cacheControlFor(`/assets/main${ext}`)).toBe(IMMUTABLE);
      },
    );

    it('treats uppercase extensions as immutable (extension is lowercased first)', () => {
      expect(svc.cacheControlFor('/assets/main.WASM')).toBe(IMMUTABLE);
    });

    it('serves multi-dot wasm path with immutable cache (last extension wins)', () => {
      expect(svc.cacheControlFor('/main.dart.wasm')).toBe(IMMUTABLE);
    });
  });

  describe('hourly cache', () => {
    it.each([
      ['/index.html', 'html entry document'],
      ['/manifest.json', 'json manifest'],
      ['/favicon.png', 'png icon'],
      ['/', 'spa root'],
      ['/settings', 'spa route without extension'],
      ['/assets/iconfont', 'assets dir entry without extension'],
    ])('serves %s (%s) with one-hour cache', (pathname) => {
      expect(svc.cacheControlFor(pathname)).toBe(HOURLY);
    });

    it('serves trailing-dot path with hourly cache (ext "." is not immutable)', () => {
      expect(svc.cacheControlFor('/file.')).toBe(HOURLY);
    });
  });
});
