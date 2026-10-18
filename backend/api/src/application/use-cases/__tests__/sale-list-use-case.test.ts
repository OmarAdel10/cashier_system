/**
 * SaleListUseCase Tests
 *
 * Covers listing sales for a tenant, the 50-result cap, the empty-list case,
 * field mapping, and dependency rejections.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SaleListUseCase } from '../sale-list-use-case';
import type { SaleListDto } from '../../dtos/sale-list.dto';
import type { SaleRepository } from 'daftari-backend-shared/domain/repositories/sale-repository';
import type { Sale } from 'daftari-backend-shared/domain/entities/sale';

const FIXED_NOW = 1_700_000_000_000;

const baseDto: SaleListDto = {
  tenantId: 'tenant-1',
  since: FIXED_NOW - 86_400_000,
};

const makeSaleRepo = (sales: Sale[] = []) => ({
  listByTenantSince: vi.fn().mockResolvedValue(sales),
});

describe('SaleListUseCase', () => {
  let saleRepo: ReturnType<typeof makeSaleRepo>;
  let useCase: SaleListUseCase;

  beforeEach(() => {
    saleRepo = makeSaleRepo();
    useCase = new SaleListUseCase(saleRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('lists sales for the tenant since the given timestamp', async () => {
    const sales = [
      {
        id: 'sale-1',
        tenantId: 'tenant-1',
        receiptJson: '{}',
        totalPiastres: 1000,
        createdAt: FIXED_NOW - 1000,
      },
      {
        id: 'sale-2',
        tenantId: 'tenant-1',
        receiptJson: '{}',
        totalPiastres: 2000,
        createdAt: FIXED_NOW,
      },
    ];
    saleRepo.listByTenantSince = vi.fn().mockResolvedValue(sales);

    const result = await useCase.execute(baseDto);

    expect(saleRepo.listByTenantSince).toHaveBeenCalledWith('tenant-1', FIXED_NOW - 86_400_000);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.sales).toEqual([
        {
          id: 'sale-1',
          tenantId: 'tenant-1',
          receiptJson: '{}',
          totalPiastres: 1000,
          createdAt: FIXED_NOW - 1000,
        },
        {
          id: 'sale-2',
          tenantId: 'tenant-1',
          receiptJson: '{}',
          totalPiastres: 2000,
          createdAt: FIXED_NOW,
        },
      ]);
    }
  });

  it('caps results at 50 sales', async () => {
    const sales = Array.from({ length: 55 }, (_, i) => ({
      id: `sale-${i}`,
      tenantId: 'tenant-1',
      receiptJson: '{}',
      totalPiastres: 1000,
      createdAt: FIXED_NOW - i * 1000,
    }));
    saleRepo.listByTenantSince = vi.fn().mockResolvedValue(sales);

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.sales).toHaveLength(50);
      expect(result.data.sales[0]?.id).toBe('sale-0');
      expect(result.data.sales[49]?.id).toBe('sale-49');
    }
  });

  it('returns an ok with an empty list when there are no sales', async () => {
    saleRepo.listByTenantSince = vi.fn().mockResolvedValue([]);

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.sales).toEqual([]);
    }
  });

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    saleRepo.listByTenantSince = vi.fn().mockRejectedValueOnce(new Error('db down'));
    await expect(useCase.execute(baseDto)).rejects.toThrow('db down');
  });
});
