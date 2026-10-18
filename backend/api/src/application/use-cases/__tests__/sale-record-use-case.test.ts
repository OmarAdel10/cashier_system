/**
 * SaleRecordUseCase Tests
 *
 * Covers record success, every error arm, missing-row no-op, device limit,
 * license expired, and dependency rejections.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SaleRecordUseCase } from '../sale-record-use-case';
import type { SaleRecordDto } from '../../dtos/sale-record.dto';
import type { SaleRepository } from 'daftari-backend-shared/domain/repositories/sale-repository';
import type { DeviceRepository } from 'daftari-backend-shared/domain/repositories/device-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';

const FIXED_NOW = 1_700_000_000_000;

const baseDto: SaleRecordDto = {
  tenantId: 'tenant-1',
  deviceHwid: 'device-1',
  receiptJson: '{}',
  totalPiastres: 1000,
  createdAt: FIXED_NOW,
};

const baseUser = {
  tenantId: 'tenant-1',
  email: 'owner@example.com',
  role: 'admin',
  tier: 'pro',
  createdAt: FIXED_NOW,
};

const makeSaleRepo = (overrides: Partial<SaleRepository> = {}) => ({
  insert: vi.fn().mockResolvedValue(undefined),
  ...overrides,
});

const makeDeviceRepo = (overrides: Partial<DeviceRepository> = {}) => ({
  listByTenant: vi.fn().mockResolvedValue([]),
  ...overrides,
});

const makeLicenseRepo = (overrides: Partial<LicenseRepository> = {}) => ({
  findLatestByTenant: vi.fn().mockResolvedValue(null),
  isExpired: vi.fn().mockResolvedValue(false),
  getDeviceLimit: vi.fn().mockReturnValue(1),
  ...overrides,
});

const makeUserRepo = (overrides: Partial<UserRepository> = {}) => ({
  findByTenantId: vi.fn().mockResolvedValue(null),
  ...overrides,
});

describe('SaleRecordUseCase', () => {
  let saleRepo: ReturnType<typeof makeSaleRepo>;
  let deviceRepo: ReturnType<typeof makeDeviceRepo>;
  let licenseRepo: ReturnType<typeof makeLicenseRepo>;
  let userRepo: ReturnType<typeof makeUserRepo>;
  let useCase: SaleRecordUseCase;

  beforeEach(() => {
    saleRepo = makeSaleRepo();
    deviceRepo = makeDeviceRepo();
    licenseRepo = makeLicenseRepo();
    userRepo = makeUserRepo();
    useCase = new SaleRecordUseCase(
      saleRepo as any,
      deviceRepo as any,
      licenseRepo as any,
      userRepo as any,
    );
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('records a sale and returns the sale id', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue(baseUser);
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      graceEnd: FIXED_NOW + 86_400_000,
    });
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(2);
    deviceRepo.listByTenant = vi.fn().mockResolvedValue([]);

    const result = await useCase.execute(baseDto);

    expect(userRepo.findByTenantId).toHaveBeenCalledWith('tenant-1');
    expect(licenseRepo.findLatestByTenant).toHaveBeenCalledWith('tenant-1');
    expect(licenseRepo.isExpired).toHaveBeenCalledWith(
      FIXED_NOW + 86_400_000,
      FIXED_NOW,
    );
    expect(licenseRepo.getDeviceLimit).toHaveBeenCalledWith('pro');
    expect(deviceRepo.listByTenant).toHaveBeenCalledWith('tenant-1');
    expect(saleRepo.insert).toHaveBeenCalledWith({
      id: expect.stringMatching(/^sale_/),
      tenantId: 'tenant-1',
      receiptJson: '{}',
      totalPiastres: 1000,
      createdAt: FIXED_NOW,
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.saleId).toMatch(/^sale_/);
    }
  });

  it('uses the starter tier device limit when no tenant profile tier is set', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue({
      ...baseUser,
      tier: undefined,
    });
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      graceEnd: FIXED_NOW + 86_400_000,
    });
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(1);
    deviceRepo.listByTenant = vi.fn().mockResolvedValue([]);

    const result = await useCase.execute(baseDto);

    expect(licenseRepo.getDeviceLimit).toHaveBeenCalledWith('starter');
    expect(result.ok).toBe(true);
  });

  it('returns MISSING_FIELDS for empty tenantId', async () => {
    const result = await useCase.execute({ ...baseDto, tenantId: '' });
    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
    expect(saleRepo.insert).not.toHaveBeenCalled();
  });

  it('returns MISSING_FIELDS for empty deviceHwid', async () => {
    const result = await useCase.execute({ ...baseDto, deviceHwid: '' });
    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('returns MISSING_FIELDS for empty receiptJson', async () => {
    const result = await useCase.execute({ ...baseDto, receiptJson: '' });
    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('returns MISSING_FIELDS for negative totalPiastres', async () => {
    const result = await useCase.execute({ ...baseDto, totalPiastres: -1 });
    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('returns MISSING_FIELDS for non-finite totalPiastres', async () => {
    const result = await useCase.execute({
      ...baseDto,
      totalPiastres: NaN,
    });
    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('returns MISSING_FIELDS for invalid createdAt', async () => {
    const result = await useCase.execute({ ...baseDto, createdAt: NaN });
    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('returns USER_NOT_FOUND when the tenant user is missing', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue(null);
    const result = await useCase.execute(baseDto);
    expect(result).toEqual({ ok: false, error: 'USER_NOT_FOUND' });
    expect(saleRepo.insert).not.toHaveBeenCalled();
  });

  it('returns ACCOUNT_DISABLED when the tenant user is inactive', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue({
      ...baseUser,
      isActive: 0,
    } as any);
    const result = await useCase.execute(baseDto);
    expect(result).toEqual({ ok: false, error: 'ACCOUNT_DISABLED' });
    expect(saleRepo.insert).not.toHaveBeenCalled();
  });

  it('returns NO_LICENSE when the tenant has no license', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue(baseUser);
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue(null);
    const result = await useCase.execute(baseDto);
    expect(result).toEqual({ ok: false, error: 'NO_LICENSE' });
    expect(saleRepo.insert).not.toHaveBeenCalled();
  });

  it('returns LICENSE_EXPIRED when the license grace has ended', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue(baseUser);
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      graceEnd: FIXED_NOW - 1,
    });
    licenseRepo.isExpired = vi.fn().mockResolvedValue(true);
    const result = await useCase.execute(baseDto);
    expect(result).toEqual({ ok: false, error: 'LICENSE_EXPIRED' });
    expect(saleRepo.insert).not.toHaveBeenCalled();
  });

  it('returns DEVICE_LIMIT_EXCEEDED when device count reaches the tier limit', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue(baseUser);
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      graceEnd: FIXED_NOW + 86_400_000,
    });
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(1);
    deviceRepo.listByTenant = vi.fn().mockResolvedValue([
      { id: 'device-1', tenantId: 'tenant-1' },
    ]);
    const result = await useCase.execute(baseDto);
    expect(result).toEqual({ ok: false, error: 'DEVICE_LIMIT_EXCEEDED' });
    expect(saleRepo.insert).not.toHaveBeenCalled();
  });

  it('returns SALE_RECORD_FAILED when insert throws', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue(baseUser);
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      graceEnd: FIXED_NOW + 86_400_000,
    });
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(1);
    deviceRepo.listByTenant = vi.fn().mockResolvedValue([]);
    saleRepo.insert = vi.fn().mockRejectedValue(new Error('db down'));
    const result = await useCase.execute(baseDto);
    expect(result).toEqual({ ok: false, error: 'SALE_RECORD_FAILED' });
  });

  it('propagates user repository rejection', async () => {
    userRepo.findByTenantId = vi.fn().mockRejectedValueOnce(new Error('db down'));
    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });

  it('propagates license repository rejection', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue(baseUser);
    licenseRepo.findLatestByTenant = vi.fn().mockRejectedValueOnce(
      new Error('db down'),
    );
    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });

  it('propagates device repository rejection', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue(baseUser);
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      graceEnd: FIXED_NOW + 86_400_000,
    });
    deviceRepo.listByTenant = vi.fn().mockRejectedValueOnce(new Error('db down'));
    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });
});
