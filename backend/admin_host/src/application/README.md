# Application Layer

Use cases that orchestrate the domain policy services to serve one
admin-host request. Depends on the domain layer (pure policies) and on
one outbound port (`AssetFetcher`); no Cloudflare bindings are
referenced here, so every use case is unit-testable with a mock port.

## Structure

- `ports/asset-fetcher.ts` — `AssetFetcher`: the testability port,
  split by branch: `fetchShell(): Promise<Response>` (SPA-fallback
  shell fetch) and `forwardOriginal(): Promise<Response>` (asset
  branch, forwards the original request verbatim). No pathname
  argument — the round-4 split makes the shell-vs-asset ambiguity and
  URL reconstruction from attacker-influenced pathnames
  unrepresentable. Consumed by the use case; the live handler
  (`src/index.ts`) implements it as a per-request inline adapter, with
  `WorkersAssetsFetcher` as the infrastructure implementation.
- `dtos/serve-request-dto.ts` — `ServeRequestDto`: the command
  (`{ method, pathname }`). Pathname-only contract — no query string.
- `use-cases/serve-request-use-case.ts` — `ServeRequestUseCase`:
  reproduces the legacy handler's observable decisions exactly, via
  constructor-injected domain services (`CachePolicyService`,
  `HeaderPolicyService`, `StaticAssetClassifier`).

## `ServeRequestUseCase.execute({ method, pathname })`

| Input | Behavior |
| --- | --- |
| GET + (`/` or not a static asset path) | `fetchShell()` — fetch `/index.html`; decorate with hourly cache + security headers **regardless of upstream status** (the shell cache key is `/index.html`, not the route path) |
| Anything else | `forwardOriginal()` — forward the original request; **status >= 400 → returned untouched** (preserved legacy behavior; hardening decision recorded in `docs/followups.md`, Plane DAFTARI-147) |
| Asset branch, status < 400 | Decorate with `CachePolicyService.cacheControlFor(pathname)` (immutable set end-to-end, else hourly) + security headers |

Decoration semantics (identical to the legacy `withHeaders`): the
security headers and `Cache-Control` are **overrides set on a copy of
the upstream response's headers** — non-conflicting upstream headers
(Content-Type, ETag) survive. Status, statusText, and body are
preserved.

## Tests

`__tests__/serve-request-use-case.test.ts` — 27 unit tests with a
mocked split-port fetcher: SPA fallback (GET `/`, routes), asset
branch via `forwardOriginal`, literal `/index.html` collision rows
(asset branch, never the shell fetch), case-insensitive immutable
end-to-end, >= 400 passthrough (untouched, identity-pinned), sub-400
non-2xx decoration (301/304/399 incl. statusText), any-status
fallback decoration (200/304/404/500 incl. statusText), non-GET
gating (incl. case-sensitive `get`/`Get` and a non-GET >= 400
untouched row), classifier short-circuit rows (never consulted for
non-GET or GET `/`), override precedence, upstream non-mutation
(bodyUsed stays false, hostile values stay on the upstream object),
raw hostile-pathname routing (`//evil.com/x.js` → asset branch),
DI routing (injected services used, no hidden defaults — cache,
classifier, and header policies each stub-pinned; command pathname
passed unmodified; shell-path cache key pinned; cache policy wins a
Cache-Control collision; an empty header-policy map leaves upstream
headers intact), error propagation — fetch rejections on
both branches plus collaborator errors (classifier, header policy,
and cache policy throws, both branches) — multi-value header survival
(double `Set-Cookie` preserved through decoration) — and sequential
instance reuse.

`__tests__/serve-request-use-case-fuzz.test.ts` — deterministic fuzz
(seeded xorshift32, 3 seeds x 200 commands) over random methods,
pathnames, and upstream statuses; hand-rolled mirrors assert routing,
passthrough, decoration, and cache-selection invariants, with
reachability guards (every branch hit per seed, plus a structurally
guaranteed GET `/` root-arm fallback outcome per seed) and a
seed-0 rejection pin (xorshift32 fixed point).

## Wiring notes

The presentation layer (`src/index.ts`) parses `request.method` /
`new URL(request.url).pathname`, constructs the use case with a
per-request inline port adapter, and delegates. The parity canary
(`test/domain-parity.test.ts`) was deleted at that step — the
layer-decidable pins (routing, >= 400 passthrough, sub-400 decoration,
any-status fallback, non-GET gating, override precedence, cache
selection) are carried by these use-case tests **and re-pinned by the
wiring tests** (`test/wiring.test.ts`) against the wired use case (a
mock fetcher here cannot catch presentation/adapter-seam drift); the
transport-fidelity pins (query strip-vs-forward, request-header and
request-body survival, method forwarding to the binding, host/origin
preservation) are likewise pinned in the wiring tests. The two
non-test obligations also landed at wiring: the wiring tests keep the
one canonical full-set security-header oracle at the wired seam, and
the `CachePolicyServiceImpl` constructor takes its classifier as a
required parameter, composed at the application root (`src/index.ts`).
