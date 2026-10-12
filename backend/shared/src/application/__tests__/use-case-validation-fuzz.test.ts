import 'reflect-metadata';
import { faker } from '@faker-js/faker';
import { describe, expect, it, vi } from 'vitest';
import { AuthLogoutUseCase } from '../use-cases/auth-logout-use-case';
import { SessionEndUseCase } from '../use-cases/session-end-use-case';
import { SessionStartUseCase } from '../use-cases/session-start-use-case';
import { SyncDataUseCase } from '../use-cases/sync-data-use-case';
import type { AuthUserRepository } from '../../domain/repositories/auth-user-repository';
import type { DeviceRepository } from '../../domain/repositories/device-repository';
import type { LicenseRepository } from '../../domain/repositories/license-repository';
import type { SaleRepository } from '../../domain/repositories/sale-repository';
import type { SessionRepository } from '../../domain/repositories/session-repository';
import type { UserRepository } from '../../domain/repositories/user-repository';

const seeds = [1101, 1202, 1303];
const operations = 100;
const blankStrings = ['', ' ', '\t'];
const invalidTimestamps = [
  null,
  Number.NaN,
  Number.POSITIVE_INFINITY,
  Number.NEGATIVE_INFINITY,
] as const;

describe('use-case input validation — deterministic fuzz', () => {
  it.each(seeds)('seed %i rejects malformed inputs without repository work', async (seed) => {
    faker.seed(seed);

    const startSessionRepo = {
      insert: vi.fn(),
      admitPosSession: vi.fn(),
      endForDevice: vi.fn(),
      endWebSessions: vi.fn(),
      getActiveForUsername: vi.fn(),
      heartbeat: vi.fn(),
      end: vi.fn(),
      endForTenant: vi.fn(),
      getLive: vi.fn(),
      getLiveWeb: vi.fn(),
      getActive: vi.fn(),
      getRecent: vi.fn(),
      getActivePos: vi.fn(),
    };
    const authUserRepo = {
      findByTenantAndUsername: vi.fn(),
      listByTenant: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      recordFailure: vi.fn(),
      reserveLoginAttempt: vi.fn(),
      releaseLoginAttempt: vi.fn(),
      convertReservationToFailure: vi.fn(),
      resetFailures: vi.fn(),
    };
    const licenseRepo = {
      upsert: vi.fn(),
      findByTenantAndDevice: vi.fn(),
      findLatestByTenant: vi.fn(),
      sweepExpired: vi.fn(),
      isExpired: vi.fn(),
      getDeviceLimit: vi.fn(),
    };
    const deviceRepo = {
      upsert: vi.fn(),
      findByTenantAndDevice: vi.fn(),
      listByTenant: vi.fn(),
    };
    const userRepo = {
      upsert: vi.fn(),
      findByTenantId: vi.fn(),
    };
    const sessionStart = new SessionStartUseCase(
      startSessionRepo as unknown as SessionRepository,
      authUserRepo as unknown as AuthUserRepository,
      licenseRepo as unknown as LicenseRepository,
      deviceRepo as unknown as DeviceRepository,
      userRepo as unknown as UserRepository,
    );

    const endSessionRepo = { end: vi.fn() };
    const logout = new AuthLogoutUseCase(
      endSessionRepo as unknown as SessionRepository,
    );
    const sessionEnd = new SessionEndUseCase(
      endSessionRepo as unknown as SessionRepository,
    );

    const syncSessionRepo = { getLive: vi.fn() };
    const saleRepo = {
      insert: vi.fn(),
      listByTenantSince: vi.fn(),
      getTenantStats: vi.fn(),
      getRecent: vi.fn(),
      getUnsyncedSince: vi.fn(),
    };
    const sync = new SyncDataUseCase(
      syncSessionRepo as unknown as SessionRepository,
      saleRepo as unknown as SaleRepository,
      deviceRepo as unknown as DeviceRepository,
      userRepo as unknown as UserRepository,
    );

    for (let operation = 0; operation < operations; operation += 1) {
      const target = operation % 4;
      const blank = () => faker.helpers.arrayElement(blankStrings);

      if (target === 0) {
        const field = faker.number.int({ min: 0, max: 2 });
        const request = {
          tenantId: 'tenant-1',
          deviceHwid: 'device-1',
          username: 'pos-1',
          source: 'pos',
        };
        if (field === 0) request.tenantId = blank();
        else if (field === 1) request.deviceHwid = blank();
        else request.username = blank();

        const result = await sessionStart.execute(request as never);
        expect(result).toMatchObject({ ok: false, error: 'MISSING_FIELDS' });
        expect(authUserRepo.findByTenantAndUsername).not.toHaveBeenCalled();
        expect(licenseRepo.findLatestByTenant).not.toHaveBeenCalled();
        expect(startSessionRepo.insert).not.toHaveBeenCalled();
        expect(startSessionRepo.admitPosSession).not.toHaveBeenCalled();
      } else if (target === 1 || target === 2) {
        const choice = faker.number.int({ min: 0, max: 2 });
        const principal = { tenantId: 'tenant-1', sessionId: 'session-1' };
        const request = {
          principal,
          sessionId: 'session-1',
        };
        if (choice === 0) principal.tenantId = blank();
        else if (choice === 1) principal.sessionId = blank();
        else request.sessionId = blank();

        const result = target === 1
          ? await logout.execute(request as never)
          : await sessionEnd.execute(request as never);
        expect(result).toMatchObject({ ok: false, error: 'MISSING_FIELDS' });
        expect(endSessionRepo.end).not.toHaveBeenCalled();
      } else {
        const choice = faker.number.int({ min: 0, max: 3 });
        const principal = { tenantId: 'tenant-1', sessionId: 'session-1' };
        const request: {
          principal: { tenantId: string; sessionId: string };
          sessionId: string;
          lastSyncTimestamp: number | null;
        } = {
          principal,
          sessionId: 'session-1',
          lastSyncTimestamp: 1000,
        };
        if (choice === 0) {
          request.lastSyncTimestamp = faker.helpers.arrayElement(invalidTimestamps);
        } else if (choice === 1) {
          principal.tenantId = blank();
        } else if (choice === 2) {
          principal.sessionId = blank();
        } else {
          request.sessionId = blank();
        }

        const result = await sync.execute(request as never);
        expect(result).toMatchObject({ ok: false, error: 'MISSING_FIELDS' });
        expect(syncSessionRepo.getLive).not.toHaveBeenCalled();
        expect(saleRepo.listByTenantSince).not.toHaveBeenCalled();
      }
    }
  });
});
