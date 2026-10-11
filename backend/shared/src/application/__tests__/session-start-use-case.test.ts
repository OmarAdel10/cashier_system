import 'reflect-metadata';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  SessionStartUseCase,
  type SessionStartDto,
  type SessionStartResponse,
} from '../use-cases/session-start-use-case';
import type { AuthUserRepository } from '../../domain/repositories/auth-user-repository';
import type { DeviceRepository } from '../../domain/repositories/device-repository';
import type { LicenseRepository } from '../../domain/repositories/license-repository';
import type { SessionRepository } from '../../domain/repositories/session-repository';
import type { UserRepository } from '../../domain/repositories/user-repository';
import { AuthServiceImpl } from '../../domain/services/auth-service.impl';

type Mock<T> = { [P in keyof T]: ReturnType<typeof vi.fn> };

const NOW = 1_769_000_000_000;

describe('SessionStartUseCase', () => {
  let useCase: SessionStartUseCase;
  let sessionRepo: Mock<SessionRepository>;
  let authUserRepo: Mock<AuthUserRepository>;
  let licenseRepo: Mock<LicenseRepository>;
  let deviceRepo: Mock<DeviceRepository>;
  let userRepo: Mock<UserRepository>;
  let validPosDto: SessionStartDto;
  let validWebDto: SessionStartDto;

  beforeEach(() => {
    vi.spyOn(Date, 'now').mockReturnValue(NOW);

    sessionRepo = {
      insert: vi.fn().mockResolvedValue(true),
      admitPosSession: vi.fn().mockResolvedValue(true),
      heartbeat: vi.fn(),
      end: vi.fn(),
      endForTenant: vi.fn(),
      endForDevice: vi.fn(),
      getLive: vi.fn(),
      getLiveWeb: vi.fn(),
      getActive: vi.fn(),
      getActiveForUsername: vi.fn(),
      getRecent: vi.fn(),
      endWebSessions: vi.fn(),
      getActivePos: vi.fn(),
    };
    authUserRepo = {
      findByTenantAndUsername: vi.fn().mockResolvedValue({
        tenantId: 'tenant-1',
        username: 'owner',
        passwordHash: 'hash',
        role: 'admin',
        displayName: 'Owner',
        mustChangePassword: 0,
        isActive: 1,
        failedAttempts: 0,
        lockedUntil: undefined,
        createdAt: NOW - 1_000,
        updatedAt: NOW - 1_000,
      }),
      listByTenant: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      recordFailure: vi.fn(),
      reserveLoginAttempt: vi.fn(),
      releaseLoginAttempt: vi.fn(),
      convertReservationToFailure: vi.fn(),
      resetFailures: vi.fn(),
    };
    licenseRepo = {
      upsert: vi.fn(),
      findByTenantAndDevice: vi.fn(),
      findLatestByTenant: vi.fn().mockResolvedValue({
        tenantId: 'tenant-1',
        deviceHwid: 'device-1',
        licenseKey: 'license-key',
        subscriptionEnd: NOW + 86_400_000,
        billingCycle: 'monthly',
        graceEnd: NOW + 86_400_000,
        status: 'active',
        createdAt: NOW - 1_000,
      }),
      sweepExpired: vi.fn(),
      isExpired: vi.fn().mockResolvedValue(false),
      getDeviceLimit: vi.fn().mockReturnValue(2),
    };
    deviceRepo = {
      upsert: vi.fn(),
      findByTenantAndDevice: vi.fn(),
      listByTenant: vi.fn(),
    };
    userRepo = {
      upsert: vi.fn(),
      findByTenantId: vi.fn().mockResolvedValue({
        tenantId: 'tenant-1',
        email: 'owner@example.test',
        role: 'admin',
        tier: 'pro',
        displayName: 'Owner',
        createdAt: NOW - 10_000,
      }),
    };

    validPosDto = {
      tenantId: 'tenant-1',
      deviceHwid: 'device-1',
      username: 'device-1',
      source: 'pos',
    };
    validWebDto = {
      tenantId: 'tenant-1',
      deviceHwid: 'web-device-1',
      username: 'owner',
      source: 'web',
    };

    useCase = new SessionStartUseCase(
      sessionRepo as unknown as SessionRepository,
      authUserRepo as unknown as AuthUserRepository,
      licenseRepo as unknown as LicenseRepository,
      deviceRepo as unknown as DeviceRepository,
      userRepo as unknown as UserRepository,
    );
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('rejects missing required fields', async () => {
    const missingFields = [
      { ...validPosDto, tenantId: '' },
      { ...validPosDto, deviceHwid: ' ' },
      { ...validPosDto, username: '' },
      { ...validPosDto, source: undefined },
    ] as Array<Partial<SessionStartDto>>;

    for (const dto of missingFields) {
      const result = await useCase.execute(dto as SessionStartDto);
      expect(result).toMatchObject({ ok: false, error: 'MISSING_FIELDS' });
    }
    expect(licenseRepo.findLatestByTenant).not.toHaveBeenCalled();
    expect(authUserRepo.findByTenantAndUsername).not.toHaveBeenCalled();
  });

  it('rejects an invalid source before repository work', async () => {
    const result = await useCase.execute({
      ...validPosDto,
      source: 'mobile' as SessionStartDto['source'],
    });

    expect(result).toMatchObject({ ok: false, error: 'INVALID_SOURCE' });
    expect(sessionRepo.insert).not.toHaveBeenCalled();
    expect(sessionRepo.admitPosSession).not.toHaveBeenCalled();
  });

  it('rejects an unknown web user', async () => {
    (authUserRepo.findByTenantAndUsername as ReturnType<typeof vi.fn>)
      .mockResolvedValue(null);

    const result = await useCase.execute(validWebDto);

    expect(result).toMatchObject({ ok: false, error: 'USER_NOT_FOUND' });
    expect(sessionRepo.endWebSessions).not.toHaveBeenCalled();
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('rejects a disabled web user', async () => {
    (authUserRepo.findByTenantAndUsername as ReturnType<typeof vi.fn>)
      .mockResolvedValue({ isActive: 0 });

    const result = await useCase.execute(validWebDto);

    expect(result).toMatchObject({ ok: false, error: 'ACCOUNT_DISABLED' });
    expect(sessionRepo.endWebSessions).not.toHaveBeenCalled();
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('ends the prior web session and admits a reconnect with a UUID session', async () => {
    const first = await useCase.execute(validWebDto);
    const second = await useCase.execute(validWebDto);

    expect(first.ok).toBe(true);
    expect(second.ok).toBe(true);
    expect(sessionRepo.endWebSessions).toHaveBeenNthCalledWith(
      1,
      'tenant-1',
      'owner',
      NOW,
    );
    expect(sessionRepo.endWebSessions).toHaveBeenNthCalledWith(
      2,
      'tenant-1',
      'owner',
      NOW,
    );
    expect(sessionRepo.insert).toHaveBeenCalledTimes(2);
    expect(sessionRepo.insert).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        tenantId: 'tenant-1',
        deviceHwid: 'web-device-1',
        username: 'owner',
        startedAt: NOW,
        heartbeatAt: NOW,
        source: 'web',
      }),
    );
    const insertedSession = (sessionRepo.insert as ReturnType<typeof vi.fn>)
      .mock.calls[1]?.[0];
    expect(insertedSession).not.toHaveProperty('endedAt');
    if (!first.ok || !second.ok) throw new Error('expected successful sessions');
    expect(first.data.sessionId).toMatch(/^sess_[0-9a-f-]{36}$/);
    expect(second.data.sessionId).toMatch(/^sess_[0-9a-f-]{36}$/);
    expect(first.data.sessionId).not.toBe(second.data.sessionId);
  });

  it('rejects a POS session when the tenant has no license', async () => {
    (licenseRepo.findLatestByTenant as ReturnType<typeof vi.fn>)
      .mockResolvedValue(null);

    const result = await useCase.execute(validPosDto);

    expect(result).toMatchObject({ ok: false, error: 'NO_LICENSE' });
    expect(deviceRepo.upsert).not.toHaveBeenCalled();
    expect(sessionRepo.admitPosSession).not.toHaveBeenCalled();
  });

  it('rejects a POS session when the license is expired', async () => {
    (licenseRepo.isExpired as ReturnType<typeof vi.fn>).mockResolvedValue(true);

    const result = await useCase.execute(validPosDto);

    expect(result).toMatchObject({ ok: false, error: 'LICENSE_EXPIRED' });
    expect(licenseRepo.isExpired).toHaveBeenCalledWith(
      NOW + 86_400_000,
      NOW,
    );
    expect(deviceRepo.upsert).not.toHaveBeenCalled();
    expect(sessionRepo.admitPosSession).not.toHaveBeenCalled();
  });

  it('upserts a POS device and admits a reconnect with the tier limit', async () => {
    const first = await useCase.execute(validPosDto);
    const second = await useCase.execute(validPosDto);

    expect(first.ok).toBe(true);
    expect(second.ok).toBe(true);
    expect(userRepo.findByTenantId).toHaveBeenCalledWith('tenant-1');
    expect(licenseRepo.getDeviceLimit).toHaveBeenCalledWith('pro');
    expect(deviceRepo.upsert).toHaveBeenNthCalledWith(1, {
      tenantId: 'tenant-1',
      deviceHwid: 'device-1',
      firstSeenAt: NOW,
      lastSeenAt: NOW,
    });
    expect(sessionRepo.endForDevice).toHaveBeenNthCalledWith(
      2,
      'tenant-1',
      'device-1',
      NOW,
    );
    expect(sessionRepo.admitPosSession).toHaveBeenCalledTimes(2);
    expect(sessionRepo.admitPosSession).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        tenantId: 'tenant-1',
        deviceHwid: 'device-1',
        username: 'device-1',
        startedAt: NOW,
        heartbeatAt: NOW,
        source: 'pos',
      }),
      2,
    );
    const admittedSession = (sessionRepo.admitPosSession as ReturnType<typeof vi.fn>)
      .mock.calls[1]?.[0];
    expect(admittedSession).not.toHaveProperty('endedAt');
    expect(sessionRepo.insert).not.toHaveBeenCalled();
    if (!first.ok || !second.ok) throw new Error('expected successful sessions');
    expect(first.data.sessionId).toMatch(/^sess_[0-9a-f-]{36}$/);
    expect(second.data.sessionId).toMatch(/^sess_[0-9a-f-]{36}$/);
    expect(first.data.sessionId).not.toBe(second.data.sessionId);
  });

  it('uses the starter POS limit when the tenant profile is absent', async () => {
    (userRepo.findByTenantId as ReturnType<typeof vi.fn>).mockResolvedValue(null);
    (licenseRepo.getDeviceLimit as ReturnType<typeof vi.fn>)
      .mockImplementation((tier: string) => (tier === 'starter' ? 1 : 2));

    const result = await useCase.execute(validPosDto);

    expect(result.ok).toBe(true);
    expect(licenseRepo.getDeviceLimit).toHaveBeenCalledWith('starter');
    expect(sessionRepo.admitPosSession).toHaveBeenCalledWith(
      expect.objectContaining({ tenantId: 'tenant-1', source: 'pos' }),
      1,
    );
  });

  it('rejects POS admission when the device limit is reached', async () => {
    (sessionRepo.admitPosSession as ReturnType<typeof vi.fn>)
      .mockResolvedValue(false);

    const result = await useCase.execute(validPosDto);

    expect(result).toMatchObject({ ok: false, error: 'SESSION_CREATION_FAILED' });
    expect(deviceRepo.upsert).toHaveBeenCalledTimes(1);
    expect(sessionRepo.endForDevice).toHaveBeenCalledTimes(1);
    expect(sessionRepo.admitPosSession).toHaveBeenCalledWith(
      expect.objectContaining({ source: 'pos' }),
      2,
    );
  });

  it('reports a failed web insert without returning a session id', async () => {
    (sessionRepo.insert as ReturnType<typeof vi.fn>).mockResolvedValue(false);

    const result = await useCase.execute(validWebDto);

    expect(result).toMatchObject({ ok: false, error: 'SESSION_CREATION_FAILED' });
    expect((result as SessionStartResponse).ok).toBe(false);
  });

  it('reports a failed POS admission without returning a session id', async () => {
    (sessionRepo.admitPosSession as ReturnType<typeof vi.fn>)
      .mockResolvedValue(false);

    const result = await useCase.execute(validPosDto);

    expect(result).toMatchObject({ ok: false, error: 'SESSION_CREATION_FAILED' });
    expect((result as SessionStartResponse).ok).toBe(false);
  });
});

describe('AuthServiceImpl.isSessionConflict', () => {
  it('conflicts only on an active web session', () => {
    const service = new AuthServiceImpl();

    expect(
      service.isSessionConflict([{ id: 'web-1', source: 'web' }]),
    ).toBe(true);
    expect(
      service.isSessionConflict([{ id: 'pos-1', source: 'pos' }]),
    ).toBe(false);
    expect(
      service.isSessionConflict([
        { id: 'web-1', source: 'web', endedAt: NOW },
      ]),
    ).toBe(false);
    expect(service.isSessionConflict([])).toBe(false);
  });
});
