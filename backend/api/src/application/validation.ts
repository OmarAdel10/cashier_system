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

export function validateDeviceHwid(v: unknown): v is string {
  return typeof v === 'string' && v.length >= 1 && v.length <= 128;
}

export function validateUsername(v: unknown): v is string {
  return typeof v === 'string' && /^[a-zA-Z0-9_]{3,30}$/.test(v);
}

export function validatePassword(v: unknown): v is string {
  return typeof v === 'string' && v.length >= 8 && v.length <= 128;
}

export function validateRole(v: unknown): v is 'admin' | 'cashier' {
  return v === 'admin' || v === 'cashier';
}

export function validateDisplayName(v: unknown): v is string | null | undefined {
  if (v === undefined || v === null) return true;
  if (typeof v !== 'string') return false;
  return v.trim() !== '';
}

export function validateIsActive(v: unknown): v is 0 | 1 {
  return v === 0 || v === 1;
}
