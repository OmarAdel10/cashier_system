import { describe, expect, it, vi } from 'vitest';
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

    it('serves /APP.JS with immutable cache (uppercase .js composition)', () => {
      expect(svc.cacheControlFor('/APP.JS')).toBe(IMMUTABLE);
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
      ['/font.woff', 'woff is not woff2'],
      ['/bundle.jsx', 'near-miss suffix stays hourly'],
      ['/x.wasmx', 'near-miss suffix stays hourly'],
      ['/a.b/main', 'dot-in-dir suffix is not immutable'],
      ['/app.js.map', 'source map gets hourly cache'],
    ])('serves %s (%s) with one-hour cache', (pathname) => {
      expect(svc.cacheControlFor(pathname)).toBe(HOURLY);
    });

    it('serves trailing-dot path with hourly cache (ext "." is not immutable)', () => {
      expect(svc.cacheControlFor('/file.')).toBe(HOURLY);
    });
  });

  describe('constructor injection', () => {
    it('delegates extension extraction to the injected classifier', () => {
      const injected = new CachePolicyServiceImpl({
        extOf: () => '.wasm',
        isStaticAssetPath: () => true,
      });
      expect(injected.cacheControlFor('/anything-at-all')).toBe(IMMUTABLE);
    });

    it('reads the injected classifier result, not a hidden default', () => {
      const injected = new CachePolicyServiceImpl({
        extOf: () => '.html',
        isStaticAssetPath: () => true,
      });
      expect(injected.cacheControlFor('/assets/main.wasm')).toBe(HOURLY);
    });

    it('routes cacheControlFor through the injected classifier', () => {
      const extOf = vi.fn(() => '.wasm');
      const injected = new CachePolicyServiceImpl({
        extOf,
        isStaticAssetPath: () => true,
      });
      injected.cacheControlFor('/routed/path');
      expect(extOf).toHaveBeenCalledWith('/routed/path');
    });
  });
});
