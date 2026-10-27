# daftari-admin (admin_host)

Cloudflare Worker that hosts the admin dashboard's Flutter web build (WASM)
as static assets — with the SPA routing, security headers, and cache policy
for a single-page app served from a Workers Static Assets binding.

## Architecture

The worker follows the clean-architecture layering used across the backend.
Every policy decision lives in exactly one layer; the outer layers only
parse, delegate, and wire.

```
src/
├── domain/services/        # Pure policy — no I/O, no Cloudflare types
│   ├── cache-policy-service(.impl).ts      Cache-Control per pathname
│   ├── header-policy-service(.impl).ts    The 8 security headers incl. CSP
│   └── static-asset-classifier(.impl).ts  Static-asset vs SPA-route rule
├── application/
│   ├── use-cases/serve-request-use-case.ts # The serve decision tree
│   ├── ports/asset-fetcher.ts               # Outbound asset port (split)
│   └── dtos/serve-request-dto.ts            # { method, pathname } command
├── index.ts                # Presentation: parse request → delegate
└── runtime.ts              # Infrastructure composition root
    └── infrastructure/     # WorkersAssetsFetcher adapter + app factory
```

- **Domain** (`src/domain/services/`): interface + impl pairs. The single
  source of truth for the cache directives, the security-header map, and the
  static-vs-SPA classification. Pure functions — unit-testable, no
  framework types.
- **Application** (`src/application/`): `ServeRequestUseCase.execute({method,
  pathname})` owns the whole serving decision: SPA fallback (GET on `/` or a
  non-asset path → fetch the `/index.html` shell, decorate with hourly cache
  and security headers regardless of upstream status), otherwise forward the
  original request; `>= 400` upstream responses pass through untouched, every
  other status gets the cache policy + security headers as **overrides** on a
  copy of the upstream headers. Dependencies are injected via the
  constructor. The outbound port is split by branch:
  `AssetFetcher.fetchShell()` (the only sanctioned URL reconstruction —
  `new Request(new URL('/index.html', request.url), request)`) and
  `AssetFetcher.forwardOriginal()` (the original request verbatim). A
  pathname never crosses the port seam.
- **Presentation** (`src/index.ts`): a thin handler. It parses
  `request.method` and `new URL(request.url).pathname` into the DTO,
  constructs the use case with a **per-request inline adapter** over
  `env.ASSETS.fetch`, and returns the result. No business logic.
- **Infrastructure** (`src/runtime.ts` + `src/infrastructure/`): the
  composition root. `createAdminHostAppFromEnv(env)` validates the
  environment fail-closed (`ASSETS` binding required), builds the
  `WorkersAssetsFetcher` adapter, and wires the real domain impls through
  `createAdminHostApp(deps)`. `wrangler.toml` points `main` at
  `src/runtime.ts`.

## COOP/COEP and Firebase popup auth

The dashboard authenticates through Firebase popup flows
(`signInWithPopup`), which need the popup to keep a handle to its opener.
That forces:

- `Cross-Origin-Opener-Policy: same-origin-allow-popups` — keeps the opener
  handle for the popup flow (a stricter COOP would break it).
- `Cross-Origin-Embedder-Policy: require-corp` — required for
  `crossOriginIsolated`, attempted for the threaded-WASM path.

Known consequence: with these values `crossOriginIsolated` ends up `false`
in practice, so Flutter runs **Skwasm single-threaded** (CanvasKit remains
the renderer). This is a deliberate tradeoff — popup auth over maximum WASM
threading — not an accident. Revisit only if the auth flow changes (e.g.
redirect-based sign-in).

## Cache policy

| Pathname shape | `Cache-Control` |
| --- | --- |
| Ends with `.wasm`, `.js`, `.mjs`, `.css`, `.woff2`, `.ttf` (case-insensitive) | `public, max-age=31536000, immutable` |
| Everything else (shell, routes, JSON, images) | `public, max-age=3600` |

The immutable set is granted by extension; the Flutter build's entry chain
is stable-named, which is a **known tracked defect** (deploys — including
security patches — do not reach returning users for up to a year). See
`docs/followups.md` (2026-10-23/24 section) for the coarse pointers and the
private Plane items for the full detail — notably the fingerprint
enforcement item (DAFTARI-134).

## Known tracked gaps

All known weaknesses are deliberately preserved legacy behavior, recorded in
`docs/followups.md` (coarse pointers) and Plane (mechanism detail):
undecorated `>= 400` / non-GET error responses (DAFTARI-147), CSP source
wildcards (DAFTARI-131), dotfile exposure (DAFTARI-145), encoded-path
handling (DAFTARI-146), CSP reporting (DAFTARI-144), trusted-types (143),
Permissions-Policy breadth (140), HSTS preload topology (137), SPA shell
staleness, and the immutable-cache defect above. None is silently ignored —
each has a recorded wiring-phase decision.

## Deployment

- `wrangler.toml`: `main = "src/runtime.ts"`; the `ASSETS` binding serves
  `public/` (gitignored — CI builds the dashboard into it with
  `flutter build web --wasm`).
- Environments: `admin-dev` / `staging` / `production`, selected via the
  `ENVIRONMENT` binding validated fail-closed at startup.
- CI (`.github/workflows/ci.yml`): the backend-workers matrix runs
  `npm test` + `npm run typecheck` for this package on every push.

## Testing

- `src/domain/__tests__/` and `src/application/__tests__/`: per-service unit
  tests plus a deterministic seeded fuzz (xorshift32, no faker) driving all
  services with pseudo-random pathnames.
- `test/wiring.test.ts`: the wired-seam suite — drives the real handler
  through a mocked `ASSETS` binding and pins every observable decision
  (routing, `>= 400` passthrough, 3xx decoration, any-status fallback,
  non-GET gating, cache per branch, hostile-header override precedence,
  query strip-vs-forward, header/body survival, case-insensitive matching,
  host preservation, per-request adapter lifetime, shell-path == cache key).
  It keeps **the one canonical full-set security-header oracle** at the
  wired seam; the unit layers keep their own oracles by design.
- Oracle discipline: expected values are verbatim hand copies of the legacy
  policy, never imports from the implementation — a change-detector
  pattern. Any drift between code and tests fails loudly.
