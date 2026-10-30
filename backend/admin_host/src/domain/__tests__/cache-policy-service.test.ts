import { describe, expect, it, vi } from 'vitest';
import { CachePolicyServiceImpl } from '../services/cache-policy-service.impl';
import { StaticAssetClassifierImpl } from '../services/static-asset-classifier.impl';

const IMMUTABLE = 'public, max-age=31536000, immutable';
const HOURLY = 'public, max-age=3600';
const SPA_SHELL = 'max-age=0, must-revalidate';
const ERROR_CACHE = 'max-age=0, must-revalidate';

describe('CachePolicyServiceImpl', () => {
  const svc = new CachePolicyServiceImpl(new StaticAssetClassifierImpl());

  describe('SPA shell', () => {
    it.each(['/', '/index.html'])(
      'serves %s with max-age=0 must-revalidate (DAFTARI-135)',
      (pathname) => {
        expect(svc.cacheControlFor(pathname)).toBe(SPA_SHELL);
      },
    );
  });

  describe('fingerprinted immutable extensions', () => {
    it.each([
      '/assets/main.a1b2c3d4.wasm',
      '/assets/runtime.abc123def.js',
      '/assets/style.feedbeef.css',
      '/main.a1b2c3d4.wasm',
    ])('serves fingerprinted %s with immutable cache (DAFTARI-134)', (pathname) => {
      expect(svc.cacheControlFor(pathname)).toBe(IMMUTABLE);
    });

    it('treats uppercase extensions as immutable (extension is lowercased first)', () => {
      expect(svc.cacheControlFor('/assets/main.A1B2C3D4.WASM')).toBe(IMMUTABLE);
    });
  });

  describe('non-fingerprinted immutable extensions', () => {
    it.each(['.wasm', '.js', '.mjs', '.css', '.woff2', '.ttf'])(
      'serves non-fingerprinted %s with hourly cache (DAFTARI-134)',
      (ext) => {
        expect(svc.cacheControlFor(`/assets/main${ext}`)).toBe(HOURLY);
      },
    );

    it('serves /main.wasm without hash with hourly cache', () => {
      expect(svc.cacheControlFor('/main.wasm')).toBe(HOURLY);
    });

    it('serves /APP.JS without hash with hourly cache', () => {
      expect(svc.cacheControlFor('/APP.JS')).toBe(HOURLY);
    });

    it('serves multi-dot non-fingerprinted wasm with hourly cache', () => {
      expect(svc.cacheControlFor('/main.dart.wasm')).toBe(HOURLY);
    });
  });

  describe('hourly cache', () => {
    it.each([
      ['/manifest.json', 'json manifest'],
      ['/favicon.png', 'png icon'],
      ['/settings', 'spa route without extension'],
      ['/assets/iconfont', 'assets dir entry without extension'],
      ['/font.woff', 'woff is not woff2'],
      ['/bundle.jsx', 'near-miss suffix stays hourly'],
      ['/x.wasmx', 'near-miss suffix stays hourly'],
      ['/a.b/main', 'dot-in-dir suffix is not immutable'],
      ['/app.js.map', 'source map gets hourly cache'],
      ['', 'empty pathname'],
      ['/.hidden', 'dotfile path gets hourly cache'],
      ['/a%2Eb', 'encoded dot path gets hourly cache'],
      ['/x.WÅSM', 'unicode-uppercase extension is not in the immutable set'],
      ['/main.wasm?v=2', 'query string in the input stays hourly'],
    ])('serves %s (%s) with one-hour cache', (pathname) => {
      expect(svc.cacheControlFor(pathname)).toBe(HOURLY);
    });

    it('serves trailing-dot path with hourly cache (ext "." is not immutable)', () => {
      expect(svc.cacheControlFor('/file.')).toBe(HOURLY);
    });
  });

  describe('error responses', () => {
    it('returns max-age=0 must-revalidate without public (DAFTARI-135)', () => {
      expect(svc.cacheControlForError()).toBe(ERROR_CACHE);
      expect(svc.cacheControlForError()).not.toContain('public');
    });
  });

  describe('constructor injection', () => {
    it('delegates extension extraction to the injected classifier', () => {
      const injected = new CachePolicyServiceImpl({
        extOf: () => '.wasm',
        isStaticAssetPath: () => true,
      });
      expect(injected.cacheControlFor('/anything-at-all.a1b2c3d4.wasm')).toBe(IMMUTABLE);
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
