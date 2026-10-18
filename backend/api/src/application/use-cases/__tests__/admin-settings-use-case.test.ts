/**
 * AdminSettingsUseCase Tests
 *
 * Covers settings mapping, license gating, and dependency rejections.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { AdminSettingsUseCase } from '../admin-settings-use-case';
import type { AdminSettingsDto } from '../../dtos/admin-settings.dto';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';

const FIXED_NOW = 1_700_000_000_000;

const baseDto: AdminSettingsDto = {
  tenantId: 'tenant-1',
};

const makeUserRepo = (overrides: { findByTenantId?: unknown } = {}) => ({
  findByTenantId: vi.fn().mockResolvedValue(overrides.findByTenantId ?? null),
});

const makeLicenseRepo = (overrides: {
  findLatestByTenant?: unknown;
  isExpired?: boolean;
  getDeviceLimit?: number;
} = {}) => ({
  findLatestByTenant: vi.fn().mockResolvedValue(overrides.findLatestByTenant ?? null),
  isExpired: vi.fn().mockResolvedValue(overrides.isExpired ?? false),
  getDeviceLimit: vi.fn().mockReturnValue(overrides.getDeviceLimit ?? 1),
});

describe('AdminSettingsUseCase', () => {
  let userRepo: ReturnType<typeof makeUserRepo>;
  let licenseRepo: ReturnType<typeof makeLicenseRepo>;
  let useCase: AdminSettingsUseCase;

  beforeEach(() => {
    userRepo = makeUserRepo();
    licenseRepo = makeLicenseRepo();
    useCase = new AdminSettingsUseCase(userRepo as any, licenseRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('returns tier, device limit, and license status for the tenant', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      tier: 'pro',
    } as any);
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: 0,
    } as any);
    licenseRepo.isExpired = vi.fn().mockResolvedValue(false);
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(2);

    const result = await useCase.execute(baseDto);

    expect(userRepo.findByTenantId).toHaveBeenCalledWith('tenant-1');
    expect(licenseRepo.findLatestByTenant).toHaveBeenCalledWith('tenant-1');
    expect(licenseRepo.isExpired).toHaveBeenCalledWith(0, FIXED_NOW);
    expect(licenseRepo.getDeviceLimit).toHaveBeenCalledWith('pro');
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.tier).toBe('pro');
      expect(result.data.deviceLimit).toBe(2);
      expect(result.data.licenseStatus).toBe('active');
    }
  });

  it('returns expired license status when license is expired', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      tier: 'starter',
    } as any);
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: FIXED_NOW - 1000,
    } as any);
    licenseRepo.isExpired = vi.fn().mockResolvedValue(true);
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(1);

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.licenseStatus).toBe('expired');
      expect(result.data.deviceLimit).toBe(1);
    }
  });

  it('returns USER_NOT_FOUND when user profile is missing', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue(null);
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue(null);

    const result = await useCase.execute(baseDto);

    expect(userRepo.findByTenantId).toHaveBeenCalledWith('tenant-1');
    expect(result).toEqual({ ok: false, error: 'USER_NOT_FOUND' });
  });

  it('defaults tier to starter when user has no tier', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
    } as any);
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: 0,
    } as any);
    licenseRepo.isExpired = vi.fn().mockResolvedValue(false);
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(1);

    const result = await useCase.execute(baseDto);

    expect(licenseRepo.getDeviceLimit).toHaveBeenCalledWith('starter');
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.tier).toBe('starter');
      expect(result.data.deviceLimit).toBe(1);
      expect(result.data.licenseStatus).toBe('active');
    }
  });

  it('returns NO_LICENSE when license is missing', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      tier: 'starter',
    } as any);
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

  it('propagates user repository rejection', async () => {
    userRepo.findByTenantId = vi.fn().mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });

  it('propagates license repository rejection on findLatestByTenant', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      tier: 'starter',
    } as any);
    licenseRepo.findLatestByTenant = vi.fn().mockRejectedValueOnce(
      new Error('db down'),
    );

    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });

  it('propagates license repository rejection on isExpired', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      tier: 'starter',
    } as any);
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: 0,
    } as any);
    licenseRepo.isExpired = vi.fn().mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });
});
