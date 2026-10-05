# Shared Feature

## Purpose

The `shared` feature is a library module that provides core domain entities, repository interfaces, domain services, and infrastructure implementations for the Daftari POS backend. It is used by all other backend features (api, realtime, paymob_webhook, admin_host) as a shared dependency.

## Responsibilities

- **Domain Layer**: Defines core business entities, value objects, repository interfaces, and domain services
- **Application Layer**: Implements use cases that orchestrate domain services and repositories
- **Infrastructure Layer**: Provides concrete implementations of repository interfaces using Turso (libSQL) database
- **Cross-cutting Concerns**: Caching, rate limiting, authentication utilities

## Architecture

```
shared/
├── src/
│   ├── domain/
│   │   ├── entities/          # Core business entities (User, License, Device, Session, AuthUser, Sale)
│   │   ├── repositories/      # Repository interfaces (contracts)
│   │   ├── services/          # Domain services (AuthService, LicenseService, RateLimiter)
│   │   └── value-objects/     # Value objects (future)
│   ├── application/
│   │   ├── use-cases/         # Application use cases (AuthLogin, SessionStart, SyncData, etc.)
│   │   ├── dtos/              # Data Transfer Objects (future)
│   │   └── services/          # Application services (future)
│   ├── infrastructure/
│   │   ├── cache/             # Caching implementations (MemoryCache)
│   │   ├── database/          # Database utilities (TursoDb)
│   │   └── repositories/      # Repository implementations (Turso*Repository, Cached*Repository)
│   └── types.ts               # Shared TypeScript types (database record shapes)
```

## Key Components

### Domain Entities

| Entity | Description |
|--------|-------------|
| `User` | Tenant owner/user profile with tier and display info |
| `License` | Device license with subscription, billing cycle, and grace period |
| `Device` | POS device registration with platform and last seen timestamps |
| `Session` | User session (POS or web) with heartbeat tracking |
| `AuthUser` | Cloud auth user (admin/cashier) with password hash and lockout tracking |
| `Sale` | Synced sale record with receipt JSON and total amount |

### Repository Interfaces

All repositories follow the Repository pattern with interfaces in the domain layer and implementations in the infrastructure layer:

- `UserRepository` - Tenant user profile CRUD
- `LicenseRepository` - License management with expiry checking
- `DeviceRepository` - Device registration and listing
- `SessionRepository` - Session lifecycle (insert, heartbeat, end, queries)
- `AuthUserRepository` - Auth user management with failure tracking
- `SaleRepository` - Sale recording and querying

### Domain Services

- `AuthService` - Password validation, owner re-auth requirements, session conflict detection, lockout calculation
- `LicenseService` - License expiry checking, device limit lookup per tier
- `RateLimiter` - Login attempt rate limiting per tenant/username

### Application Use Cases

| Use Case | Purpose |
|----------|---------|
| `AuthLoginUseCase` | Handles login flow: credentials validation, rate limiting, license check, session creation |
| `AuthLogoutUseCase` | Ends a session by ID |
| `SessionStartUseCase` | Starts new POS or web sessions with license validation |
| `SessionEndUseCase` | Explicitly ends a session |
| `SyncDataUseCase` | Synchronizes session data and unsynced sales for offline-first POS |

### Infrastructure

- **TursoDb**: Typed wrapper around `@libsql/client` with idempotent helpers for all entities
- **Turso*Repository**: Concrete implementations of repository interfaces using TursoDb
- **MemoryCache**: In-memory TTL cache with decorator pattern for repository caching
- **CachedUserRepository**: Caching decorator for UserRepository (5-minute TTL)

## Dependencies

### Internal
- None (this is the base shared library)

### External
- `@libsql/client` - Turso HTTP client for Cloudflare Workers
- `@noble/curves` - Cryptographic primitives for password hashing
- `tsyringe` - Dependency injection container
- `vitest` - Test runner

## Configuration

Environment variables required:
- `TURSO_DATABASE_URL` - libSQL database URL
- `TURSO_AUTH_TOKEN` - Database authentication token

## Testing

Run tests with:
```bash
npm test
```

Run type checking with:
```bash
npm run typecheck
```

Test structure:
- `src/**/*.test.ts` - Unit tests for utilities and domain services
- `src/application/__tests__/*.test.ts` - Use case tests with mocked repositories
- Fuzz testing applied for edge cases (malformed input, invalid IDs, etc.)

## Usage by Other Features

Other backend features import from `shared` via path aliases or relative imports:

```typescript
// Domain entities
import { User, License, Session } from 'shared/src/domain/entities';

// Repository interfaces
import { UserRepository, LicenseRepository } from 'shared/src/domain/repositories';

// Domain services
import { AuthService, LicenseService } from 'shared/src/domain/services';

// Application use cases
import { AuthLoginUseCase, SyncDataUseCase } from 'shared/src/application/use-cases';

// Infrastructure
import { TursoDb, createTurso } from 'shared/src/turso';
import { TursoUserRepository } from 'shared/src/infrastructure/repositories/turso-user-repository';
import { MemoryCache } from 'shared/src/infrastructure/cache/memory-cache';
```

## Caching Strategy

Repository-level caching uses the **decorator pattern**:
1. Base repository implements the interface (e.g., `TursoUserRepository`)
2. Caching decorator wraps it (e.g., `CachedUserRepository`)
3. Cache key format: `user:{tenantId}`
4. TTL: 5 minutes (300 seconds) for user profiles
5. Cache invalidation on `upsert`

To add caching to other repositories, create similar decorators:
```typescript
@injectable()
export class CachedLicenseRepository implements LicenseRepository {
  constructor(
    @inject('LicenseRepository') private readonly decorated: LicenseRepository,
    @inject('MemoryCache') private readonly cache: Cache<any>
  ) {}
  // ... delegate with cache get/set
}
```

## Eventual Consistency Handling

The shared feature provides building blocks for eventual consistency:

- **License validation**: Real-time check via `LicenseRepository.findLatestByTenant()` (no cache for critical path)
- **Session management**: Fresh database reads for active session queries
- **Sale sync**: Timestamp-based incremental sync via `SaleRepository.listByTenantSince()`
- **Rate limiting**: In-memory with potential for distributed cache in future

Worker-specific strategies:
- **API Worker**: Strong consistency for writes, short TTL cache for reads
- **Realtime Worker**: Fresh DB reads for license/device limit enforcement
- **Analytics Worker**: Accepts higher staleness (batch processing)

## Security

- Passwords hashed with PBKDF2-SHA512 (1,000,000 iterations)
- Login attempt tracking with exponential backoff lockout
- Session tokens with 24-hour expiry
- Device limit enforcement per pricing tier

## Deployment

The shared module is bundled with each Cloudflare Worker that depends on it. No separate deployment needed.

## Future Improvements

1. Add Redis-backed cache implementation for distributed caching
2. Implement event sourcing for audit trails
3. Add more granular value objects (Email, TenantId, etc.)
4. Extract DTOs to separate `application/dtos` folder
5. Add integration tests with testcontainers for Turso