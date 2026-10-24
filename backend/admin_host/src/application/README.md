# Application Layer

Use cases that orchestrate the domain policy services to serve one
admin-host request. Depends on the domain layer (pure policies) and on
one outbound port (`AssetFetcher`); no Cloudflare bindings are
referenced here, so every use case is unit-testable with a mock port.

## Structure

- `ports/asset-fetcher.ts` — `AssetFetcher`: the testability port.
  `fetch(pathname: string): Promise<Response>`. Consumed by the use
  case; implemented by the infrastructure adapter at the wiring step
  (Phase 3 uses a temporary inline port wrapping `env.ASSETS.fetch`;
  Phase 4 replaces it with `WorkersAssetsFetcher` + a factory).
- `dtos/serve-request-dto.ts` — `ServeRequestDto`: the command
  (`{ method, pathname }`). Pathname-only contract — no query string.
- `use-cases/serve-request-use-case.ts` — `ServeRequestUseCase`:
  reproduces the legacy handler's observable decisions exactly, via
  constructor-injected domain services (`CachePolicyService`,
  `HeaderPolicyService`, `StaticAssetClassifier`).

## `ServeRequestUseCase.execute({ method, pathname })`

| Input | Behavior |
| --- | --- |
| GET + (`/` or not a static asset path) | Fetch `/index.html` via the port; decorate with hourly cache + security headers **regardless of upstream status** (the shell cache key is `/index.html`, not the route path) |
| Anything else | Fetch the pathname via the port; **status >= 400 → returned untouched** (preserved legacy behavior; hardening decision recorded in `docs/followups.md`, Plane DAFTARI-147) |
| Asset branch, status < 400 | Decorate with `CachePolicyService.cacheControlFor(pathname)` (immutable set end-to-end, else hourly) + security headers |

Decoration semantics (identical to the legacy `withHeaders`): the
security headers and `Cache-Control` are **overrides set on a copy of
the upstream response's headers** — non-conflicting upstream headers
(Content-Type, ETag) survive. Status, statusText, and body are
preserved.

## Tests

`__tests__/serve-request-use-case.test.ts` — 13 unit tests with a
mocked fetcher: SPA fallback (GET `/`, routes), asset branch verbatim
path, case-insensitive immutable end-to-end, >= 400 passthrough,
sub-400 non-2xx decoration (301/304/399 incl. statusText), any-status
fallback decoration, non-GET gating, override precedence, DI routing
(injected services used, no hidden defaults, command pathname passed
unmodified).

`__tests__/serve-request-use-case-fuzz.test.ts` — deterministic fuzz
(seeded xorshift32, 3 seeds x 200 commands) over random methods,
pathnames, and upstream statuses; hand-rolled mirrors assert routing,
passthrough, decoration, and cache-selection invariants, with
reachability guards (every branch hit per seed).

## Wiring notes

The presentation layer (Phase 3) parses `request.method` /
`new URL(request.url).pathname`, constructs the use case with an inline
port, and delegates. The parity canary (`test/domain-parity.test.ts`)
is deleted at that step — the layer-decidable pins (routing, >= 400
passthrough, sub-400 decoration, any-status fallback, non-GET gating,
override precedence, cache selection) are carried by these use-case
tests; the transport-fidelity pins (query strip-vs-forward,
request-header/body survival, method forwarding to the binding) remain
wiring-test obligations (see `docs/followups.md`, wiring obligations
entry — the canonical list).
