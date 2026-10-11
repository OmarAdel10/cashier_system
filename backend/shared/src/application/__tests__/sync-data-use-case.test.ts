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

function createUseCase(
  sales: Sale[] = [],
  sessionOverrides: Partial<Session> = {},
) {
  const liveSession = { ...session, ...sessionOverrides };
  const sessionRepo = {
    getLive: vi.fn().mockResolvedValue(liveSession),
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

  return { useCase, sessionRepo, saleRepo, liveSession };
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
      principal: { tenantId: 'tenant-1' },
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
      principal: { tenantId: 'tenant-1' },
      sessionId: 'session-1',
      lastSyncTimestamp: 1000,
    });

    expect(result.ok).toBe(true);
    expect(sessionRepo.getLive).toHaveBeenCalledWith('tenant-1', 'session-1');
    expect(saleRepo.listByTenantSince).toHaveBeenCalledWith('tenant-1', 1000);
    expect(saleRepo.getUnsyncedSince).not.toHaveBeenCalled();
    if (!result.ok) throw new Error('expected successful sync');
    expect(result.data.unsyncedSales[0]?.tenantId).toBe('tenant-1');
  });

  it('accepts both live POS and web sessions through the source-neutral lookup', async () => {
    for (const source of ['pos', 'web'] as const) {
      const { useCase, sessionRepo } = createUseCase([], { source });

      const result = await useCase.execute({
        principal: {
          tenantId: 'tenant-1',
          sessionId: 'session-1',
          username: 'owner',
        },
        sessionId: 'session-1',
        lastSyncTimestamp: 1000,
      });

      expect(result.ok).toBe(true);
      expect(sessionRepo.getLive).toHaveBeenCalledWith('tenant-1', 'session-1');
      if (!result.ok) throw new Error(`expected successful ${source} sync`);
      expect(result.data.session.source).toBe(source);
    }
  });

  it('rejects missing or blank principal fields before repository work', async () => {
    const { useCase, sessionRepo, saleRepo } = createUseCase();
    const valid = {
      principal: { tenantId: 'tenant-1', sessionId: 'session-1' },
      sessionId: 'session-1',
      lastSyncTimestamp: 1000,
    };
    const invalidRequests = [
      { ...valid, principal: undefined },
      { ...valid, principal: { tenantId: '' } },
      { ...valid, principal: { tenantId: ' ' } },
      { ...valid, principal: { tenantId: 'tenant-1', sessionId: ' ' } },
      { ...valid, sessionId: '' },
      { ...valid, sessionId: ' ' },
    ];

    for (const request of invalidRequests) {
      const result = await useCase.execute(request as never);
      expect(result).toMatchObject({ ok: false, error: 'MISSING_FIELDS' });
    }
    expect(sessionRepo.getLive).not.toHaveBeenCalled();
    expect(saleRepo.listByTenantSince).not.toHaveBeenCalled();
  });

  it('rejects non-finite timestamps before repository work', async () => {
    const { useCase, sessionRepo } = createUseCase();
    const valid = {
      principal: { tenantId: 'tenant-1' },
      sessionId: 'session-1',
    };

    for (const lastSyncTimestamp of [null, Number.NaN, Number.POSITIVE_INFINITY]) {
      const result = await useCase.execute({
        ...valid,
        lastSyncTimestamp,
      } as never);
      expect(result).toMatchObject({ ok: false, error: 'MISSING_FIELDS' });
    }
    expect(sessionRepo.getLive).not.toHaveBeenCalled();
  });

  it('accepts timestamp zero as a valid initial sync', async () => {
    const { useCase, saleRepo } = createUseCase();

    const result = await useCase.execute({
      principal: { tenantId: 'tenant-1' },
      sessionId: 'session-1',
      lastSyncTimestamp: 0,
    });

    expect(result.ok).toBe(true);
    expect(saleRepo.listByTenantSince).toHaveBeenCalledWith('tenant-1', 0);
  });

  it('rejects a principal session mismatch before lookup', async () => {
    const { useCase, sessionRepo, saleRepo } = createUseCase();

    const result = await useCase.execute({
      principal: { tenantId: 'tenant-1', sessionId: 'session-1' },
      sessionId: 'session-2',
      lastSyncTimestamp: 1000,
    });

    expect(result).toMatchObject({ ok: false, error: 'SESSION_NOT_FOUND' });
    expect(sessionRepo.getLive).not.toHaveBeenCalled();
    expect(saleRepo.listByTenantSince).not.toHaveBeenCalled();
  });

  it('looks up unknown or ended sessions with the principal tenant', async () => {
    const { useCase, sessionRepo, saleRepo } = createUseCase();
    vi.mocked(sessionRepo.getLive).mockResolvedValue(null);

    const result = await useCase.execute({
      principal: { tenantId: 'tenant-1' },
      sessionId: 'ended-session',
      lastSyncTimestamp: 1000,
    });

    expect(result).toMatchObject({ ok: false, error: 'SESSION_NOT_FOUND' });
    expect(sessionRepo.getLive).toHaveBeenCalledWith('tenant-1', 'ended-session');
    expect(saleRepo.listByTenantSince).not.toHaveBeenCalled();
  });

  it('rejects a session owned by another username without exposing it', async () => {
    const { useCase, saleRepo } = createUseCase();

    const result = await useCase.execute({
      principal: { tenantId: 'tenant-1', username: 'other-user' },
      sessionId: 'session-1',
      lastSyncTimestamp: 1000,
    });

    expect(result).toMatchObject({ ok: false, error: 'SESSION_NOT_FOUND' });
    expect(saleRepo.listByTenantSince).not.toHaveBeenCalled();
  });
});
