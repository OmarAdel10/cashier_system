import type { AssetFetcher } from '../../application/ports/asset-fetcher';

/**
 * The env contract the deployed worker receives from wrangler:
 * the ASSETS binding (Workers Static Assets) plus the ENVIRONMENT var.
 */
export interface AssetBindings {
  ASSETS: { fetch: (request: Request) => Promise<Response> };
  ENVIRONMENT: string;
}

/**
 * Infrastructure adapter over the Workers ASSETS binding.
 *
 * Adapter obligations (from ../../application/ports/asset-fetcher.ts):
 * - Constructed PER REQUEST — an inline closure or factory over the
 *   incoming request. NEVER hold the captured request in module scope
 *   or a shared instance: on a single isolate, a shared adapter lets a
 *   later request overwrite an earlier one's stored request, and the
 *   earlier request's `forwardOriginal()` would forward the later
 *   request's Authorization headers, cookies, or body to the binding.
 * - `fetchShell` performs the ONLY sanctioned URL reconstruction:
 *   any construction keeping the original request as the init object
 *   and replacing only the path with the constant `/index.html` is
 *   acceptable; never rebuild from the raw pathname.
 * - `forwardOriginal` forwards the ORIGINAL request verbatim — host,
 *   method, full URL (query included), headers, and body.
 * - Response fidelity: return the binding's Response exactly as
 *   received. Never memoize, synthesize, filter, or rewrap.
 */
export class WorkersAssetsFetcher implements AssetFetcher {
  constructor(
    private readonly env: AssetBindings,
    private readonly request: Request,
  ) {}

  fetchShell(): Promise<Response> {
    return this.env.ASSETS.fetch(
      new Request(new URL('/index.html', this.request.url), this.request),
    );
  }

  forwardOriginal(): Promise<Response> {
    return this.env.ASSETS.fetch(this.request);
  }
}
