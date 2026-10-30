/**
 * Use case: serve one admin-host request.
 *
 * Reproduces the legacy `src/index.ts` handler's observable decisions
 * exactly, using the domain policy services:
 *
 * - SPA fallback: a GET whose pathname is `/` or does not classify as
 *   a static asset is served as the `/index.html` shell via the
 *   `AssetFetcher` port, decorated with `max-age=0, must-revalidate`
 *   and the security headers REGARDLESS of the upstream status.
 * - Asset branch: everything else is forwarded to the binding as the
 *   ORIGINAL request (forwardOriginal) and ALWAYS decorated with the
 *   security headers + cache policy (DAFTARI-147). Responses with
 *   status >= 400 get `max-age=0, must-revalidate` without `public`;
 *   all others get the normal cache policy value. No response passes
 *   through undecorated.
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
      const response = await this.deps.fetcher.fetchShell();
      return this.decorate(
        response,
        this.deps.cachePolicy.cacheControlFor(SPA_SHELL_PATH),
      );
    }

    const response = await this.deps.fetcher.forwardOriginal();
    // DAFTARI-147: decorate ALL responses, including >= 400. Error
    // responses get cache control without 'public'.
    const cacheControl =
      response.status >= 400
        ? this.deps.cachePolicy.cacheControlForError()
        : this.deps.cachePolicy.cacheControlFor(command.pathname);
    return this.decorate(response, cacheControl);
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
    // Ordering note: value-identical to the legacy withHeaders, which
    // sets Cache-Control first; iteration order differs from legacy
    // when the upstream response lacks a Cache-Control header, and no
    // client semantics depend on it. Setting it last is deliberate —
    // it keeps the cache policy authoritative if securityHeaders()
    // ever carries a Cache-Control key (pinned by test).
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  }
}
