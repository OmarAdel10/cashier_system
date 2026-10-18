/**
 * Validation Tests
 *
 * Covers the validateTenantId type guard used by every application-layer
 * use case for tenant-identity input validation.
 */
import { describe, it, expect } from 'vitest';
import { validateTenantId } from '../../validation';

describe('validateTenantId', () => {
  it('returns true for a non-empty string', () => {
    expect(validateTenantId('tenant-1')).toBe(true);
  });

  it('returns true for a padded string', () => {
    expect(validateTenantId('  tenant-1  ')).toBe(true);
  });

  it('returns false for an empty string', () => {
    expect(validateTenantId('')).toBe(false);
  });

  it('returns false for a whitespace-only string', () => {
    expect(validateTenantId('   ')).toBe(false);
  });

  it('returns false for null', () => {
    expect(validateTenantId(null)).toBe(false);
  });

  it('returns false for undefined', () => {
    expect(validateTenantId(undefined)).toBe(false);
  });

  it('returns false for a number', () => {
    expect(validateTenantId(123)).toBe(false);
  });

  it('returns false for an object', () => {
    expect(validateTenantId({})).toBe(false);
  });

  it('returns false for a boolean', () => {
    expect(validateTenantId(true)).toBe(false);
  });
});
