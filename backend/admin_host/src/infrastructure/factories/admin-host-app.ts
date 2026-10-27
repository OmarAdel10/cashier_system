import type { AssetFetcher } from '../../application/ports/asset-fetcher';
import type { CachePolicyService } from '../../domain/services/cache-policy-service';
import type { HeaderPolicyService } from '../../domain/services/header-policy-service';
import type { StaticAssetClassifier } from '../../domain/services/static-asset-classifier';
import { ServeRequestUseCase } from '../../application/use-cases/serve-request-use-case';

/**
 * Composition-root dependencies for the admin host app.
 * All collaborators are injected — no hidden defaults. The classifier
 * is stateless and shared; the fetcher is built fresh per request.
 */
export interface AdminHostAppDeps {
  fetcherFactory: (request: Request) => AssetFetcher;
  cachePolicy: CachePolicyService;
  headerPolicy: HeaderPolicyService;
  classifier: StaticAssetClassifier;
}

/**
 * Builds the request handler for the admin host. Per request this
 * composes the use case from the injected dependencies (a fresh
 * fetcher from `fetcherFactory` honoring the adapter lifetime
 * obligation), parses the presentation inputs, and delegates —
 * no policy logic lives here.
 */
export function createAdminHostApp(deps: AdminHostAppDeps): {
  fetch: (request: Request) => Promise<Response>;
} {
  return {
    async fetch(request: Request): Promise<Response> {
      const useCase = new ServeRequestUseCase({
        fetcher: deps.fetcherFactory(request),
        cachePolicy: deps.cachePolicy,
        headerPolicy: deps.headerPolicy,
        classifier: deps.classifier,
      });
      const { method } = request;
      const { pathname } = new URL(request.url);
      return useCase.execute({ method, pathname });
    },
  };
}
