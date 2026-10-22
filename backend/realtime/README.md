# Daftari Realtime — Cloudflare Worker (Durable Objects)

The realtime WebSocket hub for Daftari POS admin dashboards. A Cloudflare Worker
that holds per-tenant Durable Objects for WebSocket connection hibernation and
broadcasts sale/session events pushed by the API worker via service binding.

## Architecture

The realtime worker follows a clean-architecture layering:

```
presentation/   → src/index.ts          (Hono handlers: POST /internal/notify, GET /ws)
application/    → src/application/*     (use cases, DTOs)
domain/         → src/domain/*          (entities, repository interfaces, services, value objects)
infrastructure/ → src/infrastructure/*  (in-memory repositories, rate limiter)
```

## Routes

| Route | Method | Description | Auth |
|-------|--------|-------------|------|
| `/internal/notify` | POST | Fan-out a sale/session/sync event to a tenant's WebSocket sessions | `X-Internal-Secret` shared secret |
| `/ws` | GET | WebSocket upgrade for admin dashboard | Bearer HS256 JWT or short-lived `?ticket=` |
| `/health` | GET | Schema + secret presence check | None |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ADMIN_JWT_SECRET` | Yes | Secret for verifying admin session JWTs on `/ws` |
| `INTERNAL_NOTIFY_SECRET` | Yes | Secret for `POST /internal/notify` service binding |
| `TURSO_DB_URL` | Yes | Turso (libSQL) database URL |
| `TURSO_DB_AUTH_TOKEN` | Yes | Turso authentication token |
| `NOTIFIER` | Yes | Durable Object binding (per-tenant WebSocket hub) |

## Development

```bash
# Install dependencies
cd backend/realtime
npm install

# Typecheck
npx tsc --noEmit

# Run tests
npx vitest run

# Deploy to Cloudflare
npx wrangler deploy
```

## Testing

- **Integration tests**: `test/realtime.test.ts` — exercises full routes through mocked Durable Object
- **Unit tests**: `src/application/__tests__/*` — test individual use cases
- **Domain tests**: `src/domain/__tests__/*` — test domain services
- **Durable Object tests**: `src/__tests__/tenant-notifier.test.ts` — test TenantNotifier DO
- **Runtime tests**: `src/runtime.test.ts` — test DI wiring integration
- **Coverage threshold**: >90% statements, lines, and functions

## Clean Architecture Compliance

- **Identity fields** (tenantId) come from verified context/ticket only — never from request body/query/header.
- **No business logic in routes** — `src/index.ts` handles HTTP parsing, validation, delegation, and response formatting only; all domain logic lives in application-layer use cases.
- **No domain logic in presentation layer** — routes delegate to use cases; the Durable Object (`src/tenant_notifier.ts`) is infrastructure-only (connection hibernation + broadcast fan-out).
- **Dependency inversion** — domain defines repository/service interfaces; implementations live in `infrastructure/` (in-memory adapters for Phase 3/4, Turso-backed in Phase 6).
- **Zero Cloudflare runtime imports** in domain/application layers — `cloudflare:workers` is never imported so vitest runs in Node.

## Layers

| Layer | Directory | Responsibility |
|-------|-----------|----------------|
| Presentation | `src/index.ts` | HTTP/WebSocket parsing, delegation, response formatting |
| Application | `src/application/` | Use cases (`NotifyUseCase`, `WebSocketConnectUseCase`), DTOs |
| Domain | `src/domain/` | Entities, repository interfaces, services, value objects |
| Infrastructure | `src/infrastructure/` | In-memory repository adapters, rate limiter |

## Durable Object

One `TenantNotifier` Durable Object per tenant (id = tenant uid). Holds
hibernating WebSocket connections and broadcasts events pushed by the API
worker via `env.REALTIME.notify()`. WebSocket hibernation via
`state.acceptWebSocket` allows the DO to sleep while connections remain open —
zero duration billing when idle.
