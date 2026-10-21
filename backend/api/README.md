# Daftari API — Cloudflare Worker (Hono)

The authenticated HTTP surface for Daftari POS. A Cloudflare Worker that serves
`/auth/*`, `/sessions/*`, `/sales/*`, `/admin/*`, `/events`, and `/branding/*`
routes, backed by Turso (libSQL) and backed by application-layer use cases.

## Architecture

The API follows a clean-architecture layering:

```
presentation/   → src/routes/*          (Hono handlers, wire contract: snake_case)
application/    → src/application/*     (use cases, DTOs, validation)
domain/         → backend/shared/src/domain/* (entities, repository interfaces)
infrastructure/ → backend/shared/src/infrastructure/* (Turso repositories, KDF)
```

## Routes

| Route | Method | Description | Auth |
|-------|--------|-------------|------|
| `/auth/*` | POST | Login, sync-user, owner-refresh, session resume, profile | Firebase RS256 or HS256 session JWT |
| `/sessions/*` | POST/GET | Start, heartbeat, end, list active, revoke | Firebase owner or session admin |
| `/sales/*` | POST/GET | Sync sales, list sales | Firebase owner or session admin |
| `/admin/overview` | GET | Tenant settings (tier, device limit, license) | Admin role |
| `/admin/users` | GET/POST | List/create auth users | Admin role |
| `/admin/users/:username` | PATCH/DELETE | Update/deactivate auth user | Owner only |
| `/admin/devices/link` | POST | Link a device to tenant | Owner only |
| `/admin/devices` | GET | List devices with active sessions | Admin role |
| `/admin/activity` | GET | Recent sales + sessions feed | Admin role |
| `/events` | POST | Batched PostHog analytics | Any authenticated |
| `/branding/logo` | POST/GET | Upload/serve tenant logo SVG | Any authenticated |
| `/health` | GET | Schema + secret presence check | None |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TURSO_DATABASE_URL` | Yes | Turso database URL |
| `TURSO_AUTH_TOKEN` | Yes | Turso authentication token |
| `ADMIN_JWT_SECRET` | Yes | Secret for signing session JWTs |
| `FIREBASE_PROJECT_ID` | Yes | Firebase project for ID token verification |
| `POSTHOG_API_KEY` | Yes | PostHog API key for analytics |
| `INTERNAL_NOTIFY_SECRET` | Yes | Secret for realtime service binding |
| `REALTIME` | No | Service binding for realtime notifications |
| `LOGOS` | No | Service binding for logo storage (R2) |

## Development

```bash
# Install dependencies
cd backend/api
npm install

# Typecheck
npx tsc --noEmit

# Run tests
npx vitest run

# Run tests with coverage
npx vitest run --coverage
```

## Testing

- **Integration tests**: `test/api.test.ts` — exercises full routes through mocked Turso
- **Unit tests**: `src/application/use-cases/__tests__/*` — test individual use cases
- **Coverage threshold**: >90% statements, lines, and functions

## Clean Architecture Compliance

- **Identity fields** (tenantId, sessionId, username) come only from verified
  middleware context (`c.get('authUid')`), never from request body/query/header.
- **No business logic in routes** — all domain logic lives in application-layer
  use cases under `src/application/use-cases/`.
- **No domain logic in presentation layer** — routes handle HTTP parsing,
  validation, delegation, and response formatting only.
- **Wire contract**: snake_case in HTTP bodies/queries, camelCase in TypeScript.
