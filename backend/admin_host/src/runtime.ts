import { WorkersAssetsFetcher } from './infrastructure/adapters/workers-asset-fetcher';
import type { AssetBindings } from './infrastructure/adapters/workers-asset-fetcher';
import { createAdminHostApp } from './infrastructure/factories/admin-host-app';
import { CachePolicyServiceImpl } from './domain/services/cache-policy-service.impl';
import { HeaderPolicyServiceImpl } from './domain/services/header-policy-service.impl';
import { StaticAssetClassifierImpl } from './domain/services/static-asset-classifier.impl';

/**
 * Runtime entry: turns the wrangler-provided env into a working app.
 *
 * Fail-closed: a missing or malformed ASSETS binding throws before any
 * request is served — a mis-deployed worker fails loudly at first use
 * instead of silently serving error responses without its assets.
 */
export function createAdminHostAppFromEnv(env: AssetBindings): {
  fetch: (request: Request) => Promise<Response>;
} {
  if (!env?.ASSETS || typeof env.ASSETS.fetch !== 'function') {
    throw new Error('Missing required binding: ASSETS');
  }
  // One shared stateless classifier feeds both the cache policy and the
  // use case — divergence between the two references is impossible.
  const classifier = new StaticAssetClassifierImpl();
  return createAdminHostApp({
    fetcherFactory: (request) => new WorkersAssetsFetcher(env, request),
    cachePolicy: new CachePolicyServiceImpl(classifier),
    headerPolicy: new HeaderPolicyServiceImpl(),
    classifier,
  });
}

const handler = {
  async fetch(request: Request, env: AssetBindings): Promise<Response> {
    const app = createAdminHostAppFromEnv(env);
    return app.fetch(request);
  },
} satisfies ExportedHandler<AssetBindings>;

export default handler;
