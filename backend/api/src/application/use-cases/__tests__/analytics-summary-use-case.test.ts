/**
 * AnalyticsSummaryUseCase Tests
 *
 * Covers analytics mapping, license expiry gating, and dependency rejections.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { AnalyticsSummaryUseCase } from '../analytics-summary-use-case';
import type { AnalyticsSummaryDto } from '../../dtos/analytics-summary.dto';
import type { SaleRepository } from 'daftari-backend-shared/domain/repositories/sale-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';

const FIXED_NOW = 1_700_000_000_000;

const baseDto: AnalyticsSummaryDto = {
  tenantId: 'tenant-1',
};

const makeSaleRepo = (overrides: {
  getTenantStats?: unknown;
} = {}) => ({
  getTenantStats: vi.fn().mockResolvedValue(overrides.getTenantStats ?? {
    saleCount: 3,
    totalPiastres: 4500,
  }),
});

const makeLicenseRepo = (overrides: {
  findLatestByTenant?: unknown;
  isExpired?: boolean;
} = {}) => ({
  findLatestByTenant: vi.fn().mockResolvedValue(overrides.findLatestByTenant ?? null),
  isExpired: vi.fn().mockResolvedValue(overrides.isExpired ?? false),
});

describe('AnalyticsSummaryUseCase', () => {
  let saleRepo: ReturnType<typeof makeSaleRepo>;
  let licenseRepo: ReturnType<typeof makeLicenseRepo>;
  let useCase: AnalyticsSummaryUseCase;

  beforeEach(() => {
    saleRepo = makeSaleRepo();
    licenseRepo = makeLicenseRepo();
    useCase = new AnalyticsSummaryUseCase(saleRepo as any, licenseRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('returns total sales and total revenue for an active license', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: 0,
    } as any);
    licenseRepo.isExpired = vi.fn().mockResolvedValue(false);
    saleRepo.getTenantStats = vi.fn().mockResolvedValue({
      saleCount: 10,
      totalPiastres: 25000,
    });

    const result = await useCase.execute(baseDto);

    expect(licenseRepo.findLatestByTenant).toHaveBeenCalledWith('tenant-1');
    expect(licenseRepo.isExpired).toHaveBeenCalledWith(0, FIXED_NOW);
    expect(saleRepo.getTenantStats).toHaveBeenCalledWith('tenant-1');
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.totalSales).toBe(10);
      expect(result.data.totalRevenue).toBe(25000);
    }
  });

  it('returns NO_LICENSE when no license exists', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue(null);

    const result = await useCase.execute(baseDto);

    expect(licenseRepo.findLatestByTenant).toHaveBeenCalledWith('tenant-1');
    expect(result).toEqual({ ok: false, error: 'NO_LICENSE' });
  });

  it('returns NO_LICENSE when the license is expired', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: FIXED_NOW - 1000,
    } as any);
    licenseRepo.isExpired = vi.fn().mockResolvedValue(true);

    const result = await useCase.execute(baseDto);

    expect(licenseRepo.isExpired).toHaveBeenCalledWith(
      FIXED_NOW - 1000,
      FIXED_NOW,
    );
    expect(result).toEqual({ ok: false, error: 'NO_LICENSE' });
  });

  it('returns zeros when the tenant has no sales', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: 0,
    } as any);
    licenseRepo.isExpired = vi.fn().mockResolvedValue(false);
    saleRepo.getTenantStats = vi.fn().mockResolvedValue({
      saleCount: 0,
      totalPiastres: 0,
    });

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.totalSales).toBe(0);
      expect(result.data.totalRevenue).toBe(0);
    }
  });

  it('clamps negative totalPiastres to zero revenue', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: 0,
    } as any);
    licenseRepo.isExpired = vi.fn().mockResolvedValue(false);
    saleRepo.getTenantStats = vi.fn().mockResolvedValue({
      saleCount: 3,
      totalPiastres: -500,
    });

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.totalRevenue).toBe(0);
    }
  });

  it('returns MISSING_FIELDS for empty tenantId', async () => {
    const result = await useCase.execute({ ...baseDto, tenantId: '' });
    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('propagates license repository rejection on findLatestByTenant', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockRejectedValueOnce(
      new Error('db down'),
    );

    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });

  it('propagates license repository rejection on isExpired', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: 0,
    } as any);
    licenseRepo.isExpired = vi.fn().mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });

  it('propagates sale repository rejection on getTenantStats', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      tenantId: 'tenant-1',
      graceEnd: 0,
    } as any);
    licenseRepo.isExpired = vi.fn().mockResolvedValue(false);
    saleRepo.getTenantStats = vi.fn().mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });
});
