import { ServeRequestUseCase } from './application/use-cases/serve-request-use-case';
import type { AssetFetcher } from './application/ports/asset-fetcher';
import { CachePolicyServiceImpl } from './domain/services/cache-policy-service.impl';
import { HeaderPolicyServiceImpl } from './domain/services/header-policy-service.impl';
import { StaticAssetClassifierImpl } from './domain/services/static-asset-classifier.impl';

export interface AssetBindings {
  ASSETS: { fetch: (request: Request) => Promise<Response> };
  ENVIRONMENT: string;
}

export default {
  async fetch(request: Request, env: AssetBindings): Promise<Response> {
    // Presentation layer only: parse the command, compose the app root,
    // delegate. All serving decisions live in ServeRequestUseCase and the
    // domain services.
    const fetcher: AssetFetcher = {
      // Split-port adapter, constructed PER REQUEST over THIS request —
      // never held in module or shared instance state (ports/asset-fetcher.ts
      // lifetime obligation). fetchShell is the only sanctioned URL
      // reconstruction: the original request kept as init, only the path
      // replaced with the constant /index.html (query stripped, method /
      // headers / body preserved). forwardOriginal hands the binding the
      // original request verbatim.
      fetchShell: () =>
        env.ASSETS.fetch(
          new Request(new URL('/index.html', request.url), request),
        ),
      forwardOriginal: () => env.ASSETS.fetch(request),
    };
    // One classifier instance feeds both the cache policy and the use
    // case — a divergence between two instances is structurally
    // impossible (and the classifier is stateless, so sharing is safe).
    const classifier = new StaticAssetClassifierImpl();
    const useCase = new ServeRequestUseCase({
      fetcher,
      cachePolicy: new CachePolicyServiceImpl(classifier),
      headerPolicy: new HeaderPolicyServiceImpl(),
      classifier,
    });
    const { method } = request;
    const { pathname } = new URL(request.url);
    return useCase.execute({ method, pathname });
  },
};
