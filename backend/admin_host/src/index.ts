/**
 * Compatibility re-exports. The wrangler entry moved to `src/runtime.ts`
 * (fail-closed env validation); this module keeps the historical import
 * surface (`worker` default export + `AssetBindings`) that the wiring and
 * legacy tests were written against.
 */
export type { AssetBindings } from './infrastructure/adapters/workers-asset-fetcher';
export type { AdminHostAppDeps } from './infrastructure/factories/admin-host-app';
export { createAdminHostApp } from './infrastructure/factories/admin-host-app';
export { createAdminHostAppFromEnv } from './runtime';
export { default } from './runtime';
