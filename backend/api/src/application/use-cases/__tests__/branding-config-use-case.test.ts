/**
 * BrandingConfigUseCase Tests
 *
 * Covers branding derivation, license gating, and missing-fields validation.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { BrandingConfigUseCase } from '../branding-config-use-case';
import type { BrandingConfigDto } from '../../dtos/branding-config.dto';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';

const FIXED_NOW = 1_700_000_000_000;

const baseDto: BrandingConfigDto = {
  tenantId: 'tenant-1',
};

const makeLicenseRepo = (overrides: {
  findLatestByTenant?: unknown;
} = {}) => ({
  findLatestByTenant: vi.fn().mockResolvedValue(overrides.findLatestByTenant ?? null),
});

const makeUserRepo = (overrides: { findByTenantId?: unknown } = {}) => ({
  findByTenantId: vi.fn().mockResolvedValue(overrides.findByTenantId ?? null),
});

describe('BrandingConfigUseCase', () => {
  let licenseRepo: ReturnType<typeof makeLicenseRepo>;
  let userRepo: ReturnType<typeof makeUserRepo>;
  let useCase: BrandingConfigUseCase;

  beforeEach(() => {
    licenseRepo = makeLicenseRepo();
    userRepo = makeUserRepo();
    useCase = new BrandingConfigUseCase(licenseRepo as any, userRepo as any);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns business brand color for a business tier tenant', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: 0,
    } as any);
    userRepo.findByTenantId = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      tier: 'business',
      displayName: 'Acme Corp',
    } as any);

    const result = await useCase.execute(baseDto);

    expect(licenseRepo.findLatestByTenant).toHaveBeenCalledWith('tenant-1');
    expect(userRepo.findByTenantId).toHaveBeenCalledWith('tenant-1');
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.primaryColor).toBe('#1D4ED8');
      expect(result.data.logo).toBe('Acme Corp');
    }
  });

  it('returns default brand color for a non-business tier tenant', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: 0,
    } as any);
    userRepo.findByTenantId = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      tier: 'pro',
      displayName: undefined,
    } as any);

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.primaryColor).toBe('#3B82F6');
      expect(result.data.logo).toBeUndefined();
    }
  });

  it('returns default brand color when user profile is missing', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: 0,
    } as any);
    userRepo.findByTenantId = vi.fn().mockResolvedValue(null);

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.primaryColor).toBe('#3B82F6');
      expect(result.data.logo).toBeUndefined();
    }
  });

  it('returns NO_LICENSE when license is missing', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue(null);

    const result = await useCase.execute(baseDto);

    expect(licenseRepo.findLatestByTenant).toHaveBeenCalledWith('tenant-1');
    expect(result).toEqual({ ok: false, error: 'NO_LICENSE' });
  });

  it('returns MISSING_FIELDS for empty tenantId', async () => {
    const result = await useCase.execute({ ...baseDto, tenantId: '' });
    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('returns MISSING_FIELDS for whitespace-only tenantId', async () => {
    const result = await useCase.execute({ ...baseDto, tenantId: '   ' });
    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });
});
