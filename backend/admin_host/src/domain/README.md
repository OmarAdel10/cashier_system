# Domain Layer

Pure, dependency-free policies for serving the admin dashboard's static
assets. No I/O, no Cloudflare types, no `Request`/`Response` — only string
inputs and plain-data outputs, so every rule here is unit-testable and
intended as the single source of truth for these policies once the
application layer adopts them (wiring follows later in this phase series).

## Services

Each service is an interface (`<name>.ts`) paired with an implementation
(`<name>.impl.ts`). Consumers depend on the interface;
`CachePolicyServiceImpl` takes its classifier via constructor injection
(the parameter is required — the application root composes the impls;
see `src/index.ts`).

### `CachePolicyService`

```ts
cacheControlFor(pathname: string): string
```

Maps a URL pathname to its `Cache-Control` value:

| Pathname shape | `Cache-Control` |
| --- | --- |
| Ends with `.wasm`, `.js`, `.mjs`, `.css`, `.woff2`, `.ttf` (case-insensitive via `toLowerCase`) | `public, max-age=31536000, immutable` |
| Anything else (HTML, JSON, images, routes, `/`) | `public, max-age=3600` |

Extension-bearing build outputs get a one-year immutable cache
(fingerprint enforcement is the recorded fix for the defect below);
everything else the Flutter build regenerates on every deploy stays
hourly so updates roll out — except the
stable-named entry chain, which the defect below covers. That defect:
the deploy entry chain (`main.dart.wasm`, `main.dart.js`,
`main.dart.mjs`, `flutter.js`, `flutter_service_worker.js`,
`flutter_bootstrap.js`, `canvaskit/*`, `fonts/*.ttf`) is
**stable-named yet immutable-cached**, so deploys — including security
patches — do not reach returning users for up to a year. That is
recorded, not intended; see `docs/followups.md` (2026-10-23/24, item
on fingerprint enforcement).

Extension extraction is delegated to `StaticAssetClassifier.extOf`, keeping
the suffix rule in one place.

### `HeaderPolicyService`

```ts
securityHeaders(): Record<string, string>
```

Returns the security header map the handler applies to the responses it
decorates:

- `Cross-Origin-Embedder-Policy: require-corp`
- `Cross-Origin-Opener-Policy: same-origin-allow-popups`
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy` (`camera=(), microphone=(), geolocation=()`)
- `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`
- `Content-Security-Policy` (full policy string)

Every call returns a fresh copy — callers may mutate the result without
affecting future responses.

These are overrides set onto a copy of the upstream response's headers,
never a wholesale replacement — upstream `Content-Type`/`ETag` survive,
and `Cache-Control` comes from `CachePolicyService`.

The legacy handler (`src/index.ts`) returns asset responses with status
≥ 400 untouched, without these headers; SPA-fallback responses carry the
headers regardless of status. The application-layer wiring step must
preserve that passthrough or change it deliberately. Recommended wiring
default for a static host: apply the headers to every response,
including ≥ 400.

### `StaticAssetClassifier`

```ts
isStaticAssetPath(pathname: string): boolean
extOf(pathname: string): string
```

- `isStaticAssetPath` — `true` when the pathname contains a `.` (looks like
  a file) or starts with `/assets/`. Everything else is an SPA route and
  falls back to `index.html`.
- `extOf` — the lowercased suffix from the last `.` (e.g. `/main.dart.wasm`
  → `.wasm`, `/APP.JS` → `.js`), or `''` when there is no dot.

Method gating (the SPA fallback fires only on GET requests) is an
application-layer concern, not a domain rule.

Both rules intentionally preserve the behavior of the original
`src/index.ts` handler, including edge quirks such as `/a.b/main`
classifying as a static asset with extension `.b/main`.

## Tests

`__tests__/` holds one test file per service plus
`domain-policy-fuzz.test.ts`, which drives all three services with
deterministic pseudo-random pathnames (seeded xorshift32, three seeds ×
200 operations) and asserts the policy invariants: two-value cache control,
immutable iff extension is in the immutable-extension set, the
classification rule,
lowercase dot-suffix extraction, and constant security headers.

The parity canary that pinned the legacy handler to these services
while both copies coexisted was deleted at the wiring step: the live
handler (`src/index.ts`) now consumes the services directly, and every
canary pin is re-pinned against the wired handler in
`test/wiring.test.ts` (classification, routing, header composition with
domain values overriding conflicting upstream headers, cache values,
the ≥400 passthrough, sub-400 non-2xx (3xx) decoration, any-status
fallback decoration, non-GET method gating, query-string strip vs
forward, request-header (Accept, If-None-Match) and request-body
survival, case-insensitive extension matching, host/origin
preservation, and the per-request adapter lifetime).
