# Daftari Paymob Webhook — Cloudflare Worker (Hono)

The Paymob webhook handler for Daftari POS. A Cloudflare Worker that receives
Paymob payment callbacks, verifies HMAC-SHA512 signatures, issues Ed25519
device licenses, and upserts them into Turso. Clean architecture with separate
domain, application, and infrastructure layers.

## Architecture

The paymob_webhook worker follows a clean-architecture layering:

```
presentation/   → src/index.ts          (Hono handler: POST /webhook)
application/    → src/application/*     (use cases, DTOs)
domain/         → src/domain/*          (entities, repository interfaces, services)
infrastructure/ → src/infrastructure/*  (Turso repository, PostHog service)
```

## Routes

| Route | Method | Description | Auth |
|-------|--------|-------------|------|
| `/webhook` | POST | Paymob payment callback: verify HMAC, issue license, upsert to Turso | HMAC-SHA512 signature query param |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PAYMOB_HMAC_SECRET` | Yes | HMAC secret from Paymob dashboard for webhook verification |
| `ED25519_PRIVATE_KEY` | Yes | Base64-encoded Ed25519 private key (32-byte seed) for license signing |
| `ED25519_PUBLIC_KEY` | Yes | Base64-encoded Ed25519 public key (32 bytes) |
| `FIREBASE_PROJECT_ID` | Yes | Firebase project ID for ID token verification |
| `TURSO_DATABASE_URL` | Yes | Turso (libSQL) database URL |
| `TURSO_AUTH_TOKEN` | Yes | Turso authentication token |
| `POSTHOG_API_KEY` | Yes | PostHog API key for analytics |

## Development

```bash
# Install dependencies
cd backend/paymob_webhook
npm install

# Typecheck
npx tsc --noEmit

# Run tests
npx vitest run

# Run tests with coverage
npx vitest run --coverage

# Deploy
npx wrangler deploy
```

## Testing

- **Unit tests**: `src/domain/__tests__/*` — test domain services (HMAC validation, license signing)
- **Use case tests**: `src/application/__tests__/*` — test `ProcessWebhookUseCase` and `IssueLicenseUseCase`
- **Runtime tests**: `src/runtime.test.ts` — test DI wiring integration

## Clean Architecture Compliance

- **Presentation layer** (`src/index.ts`): handles HTTP parsing (JSON body, query params), builds DTOs, delegates to use cases, formats responses. No business logic.
- **Application layer** (`src/application/use-cases/`): `ProcessWebhookUseCase` validates HMAC, enforces idempotency and entitlement gating; `IssueLicenseUseCase` signs license keys.
- **Domain layer** (`src/domain/`): entities (`WebhookEvent`, `LicensePayload`, `LicenseDecision`), repository interface (`WebhookEventRepository`), domain services (`HmacValidationService`, `LicenseSigningService`), value objects (`LicensePayload`).
- **Infrastructure layer** (`src/infrastructure/`): `TursoWebhookEventRepository` adapter, `PostHogAnalyticsService` client.
- **Dependency injection**: `src/runtime.ts` wires all dependencies into a pre-wired Hono app via `createPaymobAppFromEnv(env)`.
- **Durable Objects**: Not used — stateless webhook handler.

## Webhook Payload

Paymob POSTs a JSON body with an `obj` field containing the 20 documented transaction fields. The worker:

1. Parses the JSON body and extracts `obj`
2. Validates the HMAC-SHA512 signature from the `hmac` query parameter
3. Checks idempotency via `transaction_id` (rejects duplicates)
4. Enforces entitlement (rejects non-successful, refunded, or voided payments)
5. Parses `merchant_order_id` as `tenant|device_hwid|billing_cycle`
6. Computes the license payload and signs it with Ed25519
7. Upserts the license into Turso (`tenant_id`, `device_hwid` unique constraint)
8. Fires-and-forgets a PostHog analytics event

## License Key Format

License keys are base64url(Ed25519 signature || JSON(LicensePayload)). The signature is generated over the canonical JSON payload using the Ed25519 private key. Verification splits the key into signature + payload, then verifies against the public key.
