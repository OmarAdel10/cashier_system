/**
 * Use case: serve one admin-host request.
 *
 * Reproduces the legacy `src/index.ts` handler's observable decisions
 * exactly, using the domain policy services:
 *
 * - SPA fallback: a GET whose pathname is `/` or does not classify as
 *   a static asset is served as the `/index.html` shell via the
 *   `AssetFetcher` port, decorated with the hourly cache and the
 *   security headers REGARDLESS of the upstream status.
 * - Asset branch: everything else is fetched by its own pathname and
 *   passed through UNTOUCHED when the upstream status is >= 400
 *   (preserved legacy behavior; the hardening decision is recorded in
 *   docs/followups.md, Plane DAFTARI-147). Otherwise it is decorated
 *   with the cache policy value (immutable set end-to-end, else
 *   hourly) and the security headers.
 * - Decoration semantics: the security headers and Cache-Control are
 *   OVERRIDES set on a copy of the upstream response's headers —
 *   upstream headers that do not conflict (e.g. Content-Type, ETag)
 *   survive. Status, statusText, and body are preserved.
 */
import type { AssetFetcher } from '../ports/asset-fetcher';
import type { ServeRequestDto } from '../dtos/serve-request-dto';
import type { CachePolicyService } from '../../domain/services/cache-policy-service';
import type { HeaderPolicyService } from '../../domain/services/header-policy-service';
import type { StaticAssetClassifier } from '../../domain/services/static-asset-classifier';

/** Path of the SPA shell the fallback branch serves. */
const SPA_SHELL_PATH = '/index.html';

/** Injected collaborators — compose at the application root. */
export interface ServeRequestUseCaseDeps {
  fetcher: AssetFetcher;
  cachePolicy: CachePolicyService;
  headerPolicy: HeaderPolicyService;
  classifier: StaticAssetClassifier;
}

export class ServeRequestUseCase {
  constructor(private readonly deps: ServeRequestUseCaseDeps) {}

  async execute(command: ServeRequestDto): Promise<Response> {
    const isSpaFallback =
      command.method === 'GET' &&
      (command.pathname === '/' ||
        !this.deps.classifier.isStaticAssetPath(command.pathname));

    if (isSpaFallback) {
      // The shell is decorated regardless of the upstream status —
      // the cache key is the shell path, not the original route.
      // Derived-hourly invariant: cacheControlFor('/index.html')
      // equals the legacy handler's hardcoded hourly directive
      // exactly while '.html' stays out of the immutable set.
      const response = await this.deps.fetcher.fetch(SPA_SHELL_PATH);
      return this.decorate(
        response,
        this.deps.cachePolicy.cacheControlFor(SPA_SHELL_PATH),
      );
    }

    const response = await this.deps.fetcher.fetch(command.pathname);
    if (response.status >= 400) {
      // Preserved legacy behavior: upstream asset errors pass
      // through untouched (see class doc + docs/followups.md).
      return response;
    }
    return this.decorate(
      response,
      this.deps.cachePolicy.cacheControlFor(command.pathname),
    );
  }

  /**
   * Overrides the policy headers onto a copy of the upstream headers
   * and rebuilds the response with status, statusText, and body intact.
   */
  private decorate(response: Response, cacheControl: string): Response {
    const headers = new Headers(response.headers);
    for (const [name, value] of Object.entries(
      this.deps.headerPolicy.securityHeaders(),
    )) {
      headers.set(name, value);
    }
    headers.set('Cache-Control', cacheControl);
    // Ordering note: the legacy withHeaders sets Cache-Control first;
    // this impl sets it last. Unobservable today because
    // securityHeaders() never carries a Cache-Control key — and
    // setting it last keeps the cache policy authoritative if that
    // ever changes.
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  }
}
