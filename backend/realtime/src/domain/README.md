# Realtime Domain Layer

Pure business rules for the `daftari-realtime` Durable Object worker. This layer
has **zero** runtime dependencies on Cloudflare workers, Hono, or the database —
it is plain TypeScript so it runs in vitest (Node) without mocking the edge
runtime.

## Surface

| Module | Purpose |
|--------|---------|
| `domain/entities/websocket-session.ts` | `WebSocketSession` + `NewWebSocketSession` |
| `domain/entities/broadcast-event.ts` | `BroadcastEvent` + `NewBroadcastEvent` |
| `domain/repositories/websocket-session-repository.ts` | `WebSocketSessionRepository` interface |
| `domain/repositories/broadcast-repository.ts` | `BroadcastRepository` interface |
| `domain/services/ticket-validation-service.ts` | `TicketValidationService` interface |
| `domain/services/broadcast-service.ts` | `BroadcastService` interface |
| `domain/value-objects/ticket.ts` | `Ticket` + `TicketValidationResult` |
| `domain/value-objects/broadcast-payload.ts` | `BroadcastPayload` |

## Conventions

- **Value objects** describe shape only — no behavior.
- **Entities** are plain interfaces with `readonly` fields; creation inputs are separate `New*` interfaces.
- **Repository interfaces** declare the persistence contract; implementations live in `infrastructure/` (Phase 4).
- **Domain service interfaces** declare pure business rules; impls live beside them as `*Impl` classes.
- **No business logic in routes** — routes parse HTTP and delegate to use cases (Phase 2).
- **Identity fields** come from verified context/ticket only, never body/query/header.

## Testing

Unit tests live in `domain/__tests__/`. Fuzz tests use deterministic seeds like the shared feature (`session-start-fuzz.test.ts`, `use-case-validation-fuzz.test.ts`).
