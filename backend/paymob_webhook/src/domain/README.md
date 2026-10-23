# Paymob Webhook Domain Layer

Pure business rules for the `daftari-paymob-webhook` Cloudflare Worker. This layer
has **zero** runtime dependencies on Cloudflare workers, Hono, or the database —
it is plain TypeScript so it runs in vitest (Node) without mocking the edge
runtime.

## Surface

| Module | Purpose |
|--------|---------|
| `domain/entities/webhook-event.ts` | `WebhookEvent` + `NewWebhookEvent` + `LicenseDecision` |
| `domain/value-objects/license-payload.ts` | `LicensePayload` + `NewLicensePayload` |
| `domain/repositories/webhook-event-repository.ts` | `WebhookEventRepository` interface |
| `domain/services/hmac-validation-service.ts` | `HmacValidationService` interface |
| `domain/services/license-signing-service.ts` | `LicenseSigningService` interface |

## Conventions

- **Value objects** describe shape only — no behavior.
- **Entities** are plain interfaces with `readonly` fields; creation inputs are separate `New*` interfaces.
- **Repository interfaces** declare the persistence contract; implementations live in `infrastructure/`.
- **Domain service interfaces** declare pure business rules; impls live beside them as `*Impl` classes.
- **No business logic in routes** — routes parse HTTP and delegate to use cases (Phase 2).
- **Identity fields** come from verified context/ticket only, never body/query/header.
- **Idempotency** — duplicate Paymob callbacks are rejected via transaction-id uniqueness.
