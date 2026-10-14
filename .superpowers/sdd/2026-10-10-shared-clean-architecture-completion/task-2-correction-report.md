# Task 2 Correction Report: Shared camelCase API Contract

## Status

Completed locally on branch `feature/shared-clean-architecture`, based on `fe05ca3`. The backend/shared public TypeScript contract was restored to camelCase without changing SQL/database identifiers, migrations, or the existing API/realtime architecture.

## Correction scope

- Restored the shared public records and DTOs in `backend/shared/src/types.ts` to camelCase:
  - `UserProfile`
  - `LicensePayload`
  - `LicenseRecord`
  - `DeviceRecord`
  - `SessionRecord`
  - `AuthUserRecord`
  - `NewAuthUser`
  - `SaleRecord`
- Restored public Turso input/output methods in `backend/shared/src/turso.ts` to camelCase while preserving:
  - snake_case SQL column names and row indexes
  - snake_case database and migration SQL
  - repository/data-access behavior
- Updated all Turso repository mappers and DTO callers under `backend/shared/src/infrastructure/repositories/` so they consume and expose camelCase shared records.
- Kept `backend/shared/src/index.ts` as the wildcard public barrel; it already exports the corrected types and methods from their source modules.
- Updated the shared login use case to emit a camelCase profile while preserving all prior security behavior.
- Updated API references only at the shared-record and HTTP wire boundaries. Existing API route structure, business logic, DI patterns, and external snake_case wire responses remain unchanged.
- Realtime retained its existing HTTP wire contract and business logic. The only realtime change is enabling `experimentalDecorators` in `backend/realtime/tsconfig.json` because its typecheck consumes shared decorator-based code.

## Preserved security behavior

The security fixes from `7c3c045` and `fe05ca3` remain intact:

- Bounded exponential account lockout with an elapsed-lock reset path.
- Login rate-limit success-window reset.
- Signed HS256 session JWT minting and verification.
- Owner email preservation when persisting timestamps.
- `lastAuthSuccessAt` / `getLastAuthSuccessAt` semantics.
- Uniform rate-limit and lockout responses that do not expose lock metadata for enumeration.
- Owner re-auth freshness and active-account session revocation checks.

## Focused contract tests

Added `backend/shared/src/public-api-contract.test.ts`, which proves exact camelCase key sets for:

- `UserProfile`
- `LicenseRecord`
- `DeviceRecord`
- `SessionRecord`
- `AuthUserRecord`
- `SaleRecord`

The database row fixtures remain snake_case, proving that the SQL-to-public-record boundary maps database rows to camelCase TypeScript DTOs.

## Verification

All commands were run from the requested worktree.

### `backend/shared`

- `npm run typecheck`: passed
- `npm test -- --reporter=dot`: passed
- Result: **12 files, 141 tests**

### `backend/api`

- `npm run typecheck`: passed
- `npm test -- --reporter=dot`: passed
- Result: **1 file, 147 tests**

### `backend/realtime`

- `npm run typecheck`: passed
- `npm test -- --reporter=dot`: passed
- Result: **1 file, 13 tests**

Additional checks:

- `git diff --check`: passed
- Working tree reviewed before commit
- No generated `node_modules` files staged

## Residual concerns

- Existing API and realtime HTTP wire contracts intentionally remain snake_case. Shared TypeScript callers now translate at the boundary.
- Realtime required `experimentalDecorators` because its TypeScript configuration compiles shared decorator-based code; this is a compilation configuration fix, not an architecture migration.

## Fix round 1: `/admin/devices` wire key leakage

The `/admin/devices` route already maps each shared `DeviceRecord` explicitly to the existing snake_case HTTP wire shape and does not spread the record. The focused API test was strengthened to assert the exact top-level and nested `active_session` key sets, so any camelCase or extra shared key causes a failure. API typecheck and tests passed after the change.
