import 'reflect-metadata';
import { faker } from '@faker-js/faker';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { SessionStartUseCase } from '../use-cases/session-start-use-case';
import type { AuthUserRepository } from '../../domain/repositories/auth-user-repository';
import type { DeviceRepository } from '../../domain/repositories/device-repository';
import type { LicenseRepository } from '../../domain/repositories/license-repository';
import type { SessionRepository } from '../../domain/repositories/session-repository';
import type { UserRepository } from '../../domain/repositories/user-repository';
import { TIER_DEVICE_LIMITS } from '../../types';

const NOW = 1_769_000_000_000;
const seeds = [701, 808, 909];
const operations = 100;

describe('SessionStartUseCase — deterministic POS admission fuzz', () => {
  beforeEach(() => {
    vi.spyOn(Date, 'now').mockReturnValue(NOW);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it.each(seeds)('seed %i never exceeds its randomized device limit', async (seed) => {
    faker.seed(seed);
    const tier = faker.helpers.arrayElement(['starter', 'pro', 'business'] as const);
    const limit = Object.prototype.hasOwnProperty.call(TIER_DEVICE_LIMITS, tier) ? TIER_DEVICE_LIMITS[tier] : 1;
    const live = new Map<string, string>();

    const sessionRepo = {
      insert: vi.fn().mockResolvedValue(true),
      admitPosSession: vi.fn(async (session: { id: string; deviceHwid: string }, selectedLimit: number) => {
        live.delete(session.deviceHwid);
        if (live.size >= selectedLimit) return false;
        live.set(session.deviceHwid, session.id);
        return true;
      }),
      endForDevice: vi.fn(async (_tenantId: string, deviceHwid: string) => {
        live.delete(deviceHwid);
      }),
      endWebSessions: vi.fn(),
      getActiveForUsername: vi.fn().mockResolvedValue([]),
      heartbeat: vi.fn(),
      end: vi.fn(),
      endForTenant: vi.fn(),
      getLive: vi.fn(),
      getLiveWeb: vi.fn(),
      getActive: vi.fn().mockResolvedValue([]),
      getRecent: vi.fn().mockResolvedValue([]),
      getActivePos: vi.fn().mockResolvedValue([]),
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
      findLatestByTenant: vi.fn().mockResolvedValue({
        tenantId: 'tenant-1',
        deviceHwid: 'license-device',
        licenseKey: 'license-key',
        subscriptionEnd: NOW + 86_400_000,
        billingCycle: 'monthly',
        graceEnd: NOW + 86_400_000,
        status: 'active',
        createdAt: NOW - 1_000,
      }),
      sweepExpired: vi.fn(),
      isExpired: vi.fn().mockResolvedValue(false),
      getDeviceLimit: vi.fn((requestedTier: string) =>
        TIER_DEVICE_LIMITS[requestedTier] ?? 1),
    };
    const deviceRepo = {
      upsert: vi.fn(),
      findByTenantAndDevice: vi.fn(),
      listByTenant: vi.fn(),
    };
    const userRepo = {
      upsert: vi.fn(),
      findByTenantId: vi.fn().mockResolvedValue({
        tenantId: 'tenant-1',
        email: 'owner@example.test',
        role: 'admin',
        tier,
        displayName: 'Owner',
        createdAt: NOW - 10_000,
      }),
    };
    const useCase = new SessionStartUseCase(
      sessionRepo as unknown as SessionRepository,
      authUserRepo as unknown as AuthUserRepository,
      licenseRepo as unknown as LicenseRepository,
      deviceRepo as unknown as DeviceRepository,
      userRepo as unknown as UserRepository,
    );

    for (let operation = 0; operation < operations; operation += 1) {
      const deviceIndex = faker.number.int({ min: 0, max: limit + 1 });
      const deviceHwid = `device-${deviceIndex}`;
      const previousSessionId = live.get(deviceHwid);
      const sizeBefore = live.size;
      const result = await useCase.execute({
        tenantId: 'tenant-1',
        deviceHwid,
        username: `pos-${deviceIndex}`,
        source: 'pos',
      });

      expect(live.size).toBeLessThanOrEqual(limit);
      if (previousSessionId !== undefined) {
        expect(result).toMatchObject({ ok: true });
        const replacementSessionId = live.get(deviceHwid);
        expect(replacementSessionId).toBeDefined();
        expect(replacementSessionId).not.toBe(previousSessionId);
      } else if (sizeBefore >= limit) {
        const selectedLimit = sessionRepo.admitPosSession.mock.calls.at(-1)?.[1];
        expect(
          result,
          `tier=${tier} limit=${limit} selected=${selectedLimit} before=${sizeBefore} live=${live.size}`,
        ).toMatchObject({
          ok: false,
          error: 'SESSION_CREATION_FAILED',
        });
        expect(live.has(deviceHwid)).toBe(false);
      } else {
        expect(result).toMatchObject({ ok: true });
        const admittedSessionId = live.get(deviceHwid);
        expect(admittedSessionId).toBeDefined();
        if (result.ok) {
          expect(admittedSessionId).toBe(result.data.sessionId);
        }
      }
    }
  });
});
