import 'reflect-metadata';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { SyncDataUseCase } from '../use-cases/sync-data-use-case';
import type { Sale } from '../../domain/entities/sale';
import type { Session } from '../../domain/entities/session';
import type { DeviceRepository } from '../../domain/repositories/device-repository';
import type { SaleRepository } from '../../domain/repositories/sale-repository';
import type { SessionRepository } from '../../domain/repositories/session-repository';
import type { UserRepository } from '../../domain/repositories/user-repository';

const session: Session = {
  id: 'session-1',
  tenantId: 'tenant-1',
  deviceHwid: 'web-device-1',
  username: 'owner',
  startedAt: 500,
  heartbeatAt: 600,
  endedAt: undefined,
  source: 'web',
};

function createUseCase(sales: Sale[]) {
  const sessionRepo = {
    getLiveWeb: vi.fn().mockResolvedValue(session),
  };
  const saleRepo = {
    insert: vi.fn(),
    listByTenantSince: vi.fn().mockResolvedValue(sales),
    getTenantStats: vi.fn(),
    getRecent: vi.fn(),
    getUnsyncedSince: vi.fn(),
  };
  const deviceRepo = {};
  const userRepo = {};

  const useCase = new SyncDataUseCase(
    sessionRepo as unknown as SessionRepository,
    saleRepo as unknown as SaleRepository,
    deviceRepo as unknown as DeviceRepository,
    userRepo as unknown as UserRepository,
  );

  return { useCase, sessionRepo, saleRepo };
}

describe('SyncDataUseCase', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('returns only verified sale fields with honest mapped values', async () => {
    const { useCase } = createUseCase([
      {
        id: 'sale-1',
        tenantId: 'tenant-1',
        receiptJson: '{"total":1250}',
        totalPiastres: 1250,
        createdAt: 3000,
      },
      {
        id: 'sale-2',
        tenantId: 'tenant-1',
        receiptJson: '',
        totalPiastres: 250,
        createdAt: 4000,
      },
    ]);

    const result = await useCase.execute({
      tenantId: 'tenant-1',
      sessionId: 'session-1',
      lastSyncTimestamp: 1000,
    });

    if (!result.ok) throw new Error('expected successful sync');
    expect(result.data.unsyncedSales).toHaveLength(2);
    expect(result.data.unsyncedSales[0]).toEqual({
      id: 'sale-1',
      tenantId: 'tenant-1',
      amount: 1250,
      createdAt: 3000,
      receiptJson: '{"total":1250}',
    });
    expect(Object.keys(result.data.unsyncedSales[0] ?? {})).toEqual([
      'id',
      'tenantId',
      'amount',
      'createdAt',
      'receiptJson',
    ]);
    expect(result.data.unsyncedSales[1]).toEqual({
      id: 'sale-2',
      tenantId: 'tenant-1',
      amount: 250,
      createdAt: 4000,
    });
    expect(Object.keys(result.data.unsyncedSales[1] ?? {})).toEqual([
      'id',
      'tenantId',
      'amount',
      'createdAt',
    ]);
    expect(result.data.unsyncedSales[0]).not.toHaveProperty('items');
    expect(result.data.unsyncedSales[0]).not.toHaveProperty('paymentMethod');
    expect(result.data.unsyncedSales[0]).not.toHaveProperty('status');
    expect(result.data.unsyncedSales[0]).not.toHaveProperty('updatedAt');
  });

  it('remains scoped to the authenticated tenant and never uses the global path', async () => {
    const { saleRepo, sessionRepo, useCase } = createUseCase([
      {
        id: 'sale-1',
        tenantId: 'tenant-1',
        receiptJson: '{}',
        totalPiastres: 500,
        createdAt: 2000,
      },
    ]);

    const result = await useCase.execute({
      tenantId: 'tenant-1',
      sessionId: 'session-1',
      lastSyncTimestamp: 1000,
    });

    expect(result.ok).toBe(true);
    expect(sessionRepo.getLiveWeb).toHaveBeenCalledWith('tenant-1', 'session-1');
    expect(saleRepo.listByTenantSince).toHaveBeenCalledWith('tenant-1', 1000);
    expect(saleRepo.getUnsyncedSince).not.toHaveBeenCalled();
    if (!result.ok) throw new Error('expected successful sync');
    expect(result.data.unsyncedSales[0]?.tenantId).toBe('tenant-1');
  });
});
