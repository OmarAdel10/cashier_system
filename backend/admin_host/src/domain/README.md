# Domain Layer

Pure, dependency-free policies for serving the admin dashboard's static
assets. No I/O, no Cloudflare types, no `Request`/`Response` — only string
inputs and plain-data outputs, so every rule here is unit-testable and
shared by the application layer as the single source of truth.

## Services

Each service is an interface (`<name>.ts`) paired with an implementation
(`<name>.impl.ts`). Consumers depend on the interface; the default
implementation is injected at construction time.

### `CachePolicyService`

```ts
cacheControlFor(pathname: string): string
```

Maps a URL pathname to its `Cache-Control` value:

| Pathname shape | `Cache-Control` |
| --- | --- |
| Ends with `.wasm`, `.js`, `.mjs`, `.css`, `.woff2`, `.ttf` (case-insensitive) | `public, max-age=31536000, immutable` |
| Anything else (HTML, JSON, images, routes, `/`) | `public, max-age=3600` |

Fingerprinted build outputs get a one-year immutable cache; everything the
Flutter build regenerates on every deploy stays hourly so updates roll out.

Extension extraction is delegated to `StaticAssetClassifier.extOf`, keeping
the suffix rule in one place.

### `HeaderPolicyService`

```ts
securityHeaders(): Record<string, string>
```

Returns the security header map applied to every response:

- `Cross-Origin-Embedder-Policy: require-corp`
- `Cross-Origin-Opener-Policy: same-origin-allow-popups`
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy` (camera, microphone, geolocation, and more denied)
- `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`
- `Content-Security-Policy` (full policy string)

Every call returns a fresh copy — callers may mutate the result without
affecting future responses.

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

Both rules intentionally preserve the behavior of the original
`src/index.ts` handler, including edge quirks such as `/a.b/main`
classifying as a static asset with extension `.b/main`.

## Tests

`__tests__/` holds one test file per service plus
`domain-policy-fuzz.test.ts`, which drives all three services with
deterministic pseudo-random pathnames (seeded xorshift32, three seeds ×
200 operations) and asserts the policy invariants: two-value cache control,
immutable iff extension in the fingerprinted set, the classification rule,
lowercase dot-suffix extraction, and constant security headers.
