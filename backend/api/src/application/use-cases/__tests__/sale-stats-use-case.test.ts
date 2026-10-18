/**
 * SaleStatsUseCase Tests
 *
 * Covers tenant sales stats mapping and dependency rejections.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SaleStatsUseCase } from '../sale-stats-use-case';
import type { SaleStatsDto } from '../../dtos/sale-stats.dto';
import type { SaleRepository } from 'daftari-backend-shared/domain/repositories/sale-repository';

const FIXED_NOW = 1_700_000_000_000;

const baseDto: SaleStatsDto = {
  tenantId: 'tenant-1',
};

const makeSaleRepo = (overrides: { saleCount?: number; totalPiastres?: number } = {}) => ({
  getTenantStats: vi.fn().mockResolvedValue({
    saleCount: overrides.saleCount ?? 3,
    totalPiastres: overrides.totalPiastres ?? 4500,
  }),
});

describe('SaleStatsUseCase', () => {
  let saleRepo: ReturnType<typeof makeSaleRepo>;
  let useCase: SaleStatsUseCase;

  beforeEach(() => {
    saleRepo = makeSaleRepo();
    useCase = new SaleStatsUseCase(saleRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('returns total sales and total revenue for the tenant', async () => {
    saleRepo.getTenantStats = vi.fn().mockResolvedValue({
      saleCount: 7,
      totalPiastres: 12300,
    });

    const result = await useCase.execute(baseDto);

    expect(saleRepo.getTenantStats).toHaveBeenCalledWith('tenant-1');
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.totalSales).toBe(7);
      expect(result.data.totalRevenue).toBe(12300);
    }
  });

  it('returns zeros when the tenant has no sales', async () => {
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

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    saleRepo.getTenantStats = vi.fn().mockRejectedValueOnce(new Error('db down'));
    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
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
