import 'reflect-metadata';
import { describe, expect, it, vi } from 'vitest';
import { TursoSaleRepository } from './turso-sale-repository';
import type { TursoDb } from '../../turso';

describe('TursoSaleRepository', () => {
  it('getUnsyncedSince uses the global query and maps Sale entities', async () => {
    const listAllSalesSince = vi.fn().mockResolvedValue([
      {
        id: 'sale-1',
        tenantId: 'tenant-1',
        receiptJson: '{"total":1000}',
        totalPiastres: 1000,
        createdAt: 2000,
      },
      {
        id: 'sale-2',
        tenantId: 'tenant-2',
        receiptJson: '{}',
        totalPiastres: 250,
        createdAt: 3000,
      },
    ]);
    const repository = new TursoSaleRepository({
      listAllSalesSince,
    } as unknown as TursoDb);

    const sales = await repository.getUnsyncedSince(1000);

    expect(listAllSalesSince).toHaveBeenCalledWith(1000);
    expect(sales).toEqual([
      {
        id: 'sale-1',
        tenantId: 'tenant-1',
        receiptJson: '{"total":1000}',
        totalPiastres: 1000,
        createdAt: 2000,
      },
      {
        id: 'sale-2',
        tenantId: 'tenant-2',
        receiptJson: '{}',
        totalPiastres: 250,
        createdAt: 3000,
      },
    ]);
    expect(Object.keys(sales[0] ?? {})).toEqual([
      'id',
      'tenantId',
      'receiptJson',
      'totalPiastres',
      'createdAt',
    ]);
  });

  it('getRecent preserves the newest-first order from TursoDb', async () => {
    const getRecentSales = vi.fn().mockResolvedValue([
      { id: 'sale-newest', totalPiastres: 300, createdAt: 3000 },
      { id: 'sale-old', totalPiastres: 100, createdAt: 1000 },
    ]);
    const repository = new TursoSaleRepository({
      getRecentSales,
    } as unknown as TursoDb);

    const sales = await repository.getRecent('tenant-1', 2);

    expect(getRecentSales).toHaveBeenCalledWith('tenant-1', 2);
    expect(sales.map((sale) => sale.id)).toEqual(['sale-newest', 'sale-old']);
    expect(sales.map((sale) => sale.createdAt)).toEqual([3000, 1000]);
  });
});
