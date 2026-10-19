/**
 * Shared input validation helpers for API application-layer use cases.
 *
 * Centralizes the tenant-identity guard so every use case validates DTO
 * identity fields identically instead of redeclaring an inline
 * `isNonEmptyString` predicate per file.
 */
export function validateTenantId(v: unknown): v is string {
  return typeof v === 'string' && v.trim().length > 0;
}
