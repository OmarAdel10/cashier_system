import 'reflect-metadata';
import { faker } from '@faker-js/faker';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { verifySessionJwt } from '../../session_jwt';
import { SessionTokenServiceImpl } from '../../application/services/session-token-service';
import {
  AuthLoginUseCase,
  type LoginDto,
  type LoginResponse,
} from '../use-cases/auth-login-use-case';
import type { AuthUserRepository } from '../../domain/repositories/auth-user-repository';
import type { SessionRepository } from '../../domain/repositories/session-repository';
import type { LicenseRepository } from '../../domain/repositories/license-repository';
import type { UserRepository } from '../../domain/repositories/user-repository';
import type { AuthService } from '../../domain/services/auth-service';
import type { RateLimiter } from '../../domain/services/rate-limiter';
import { DUMMY_HASH } from '../../password_kdf';

type Mock<T> = { [P in keyof T]: ReturnType<typeof vi.fn> };

const SECRET = 'test-admin-jwt-secret';

function authUser(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    tenantId: 'tenant-1',
    username: 'owner',
    passwordHash: 'hash',
    role: 'admin',
    displayName: 'Owner',
    mustChangePassword: 0,
    isActive: 1,
    failedAttempts: 0,
    lockedUntil: undefined,
    createdAt: Date.now(),
    updatedAt: Date.now(),
    ...overrides,
  };
}

describe('AuthLoginUseCase', () => {
  let useCase: AuthLoginUseCase;
  let authUserRepo: Mock<AuthUserRepository>;
  let sessionRepo: Mock<SessionRepository>;
  let licenseRepo: Mock<LicenseRepository>;
  let userRepo: Mock<UserRepository>;
  let authService: Mock<AuthService>;
  let rateLimiter: Mock<RateLimiter>;
  let validDto: LoginDto;

  beforeEach(() => {
    authUserRepo = {
      findByTenantAndUsername: vi.fn(),
      listByTenant: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      recordFailure: vi.fn(),
      reserveLoginAttempt: vi.fn().mockResolvedValue(true),
      releaseLoginAttempt: vi.fn(),
      convertReservationToFailure: vi.fn(),
      resetFailures: vi.fn(),
    };
    sessionRepo = {
      getActiveForUsername: vi.fn().mockResolvedValue([]),
      endWebSessions: vi.fn(),
      insert: vi.fn().mockResolvedValue(true),
      admitPosSession: vi.fn(),
      heartbeat: vi.fn(),
      end: vi.fn(),
      endForTenant: vi.fn(),
      endForDevice: vi.fn(),
      getLiveWeb: vi.fn(),
      getActive: vi.fn(),
      getRecent: vi.fn(),
      getActivePos: vi.fn(),
    };
    licenseRepo = {
      findLatestByTenant: vi.fn().mockResolvedValue({
        tenantId: 'tenant-1',
        deviceHwid: 'device',
        licenseKey: 'key',
        subscriptionEnd: Date.now() + 86400000,
        billingCycle: 'monthly',
        graceEnd: 0,
        status: 'active',
        createdAt: Date.now(),
      }),
      isExpired: vi.fn().mockReturnValue(false),
      upsert: vi.fn(),
      findByTenantAndDevice: vi.fn(),
      sweepExpired: vi.fn(),
      getDeviceLimit: vi.fn().mockReturnValue(1),
    };
    userRepo = {
      upsert: vi.fn(),
      findByTenantId: vi.fn().mockResolvedValue({
        tenantId: 'tenant-1',
        email: 'owner@example.test',
        role: 'admin',
        tier: 'pro',
        displayName: 'Owner',
        createdAt: Date.now(),
        lastLoginAt: undefined,
        lastOwnerLoginAt: undefined,
      }),
    };
    authService = {
      validateCredentials: vi.fn().mockResolvedValue(true),
      shouldRequireOwnerReauth: vi.fn().mockReturnValue(false),
      isSessionConflict: vi.fn().mockReturnValue(false),
      calculateLockout: vi.fn().mockReturnValue(null),
    };
    rateLimiter = {
      checkLimit: vi.fn().mockResolvedValue({ allowed: true, retryAfterMs: 0 }),
      recordAttempt: vi.fn(),
    };

    validDto = {
      tenantId: 'tenant-1',
      username: 'owner',
      password: 'correct-password',
      ip: faker.internet.ip(),
    };

    useCase = new AuthLoginUseCase(
      authUserRepo as unknown as AuthUserRepository,
      sessionRepo as unknown as SessionRepository,
      licenseRepo as unknown as LicenseRepository,
      userRepo as unknown as UserRepository,
      authService as unknown as AuthService,
      rateLimiter as unknown as RateLimiter,
      new SessionTokenServiceImpl(),
      SECRET,
    );
    (authUserRepo.findByTenantAndUsername as ReturnType<typeof vi.fn>)
      .mockResolvedValue(authUser());
  });

  it('rejects a bad password, records one failure, and never disables the account', async () => {
    (authService.validateCredentials as ReturnType<typeof vi.fn>).mockResolvedValue(false);

    const result = await useCase.execute(validDto) as LoginResponse;

    expect(result).toMatchObject({ ok: false, error: 'BAD_CREDENTIALS' });
    expect(authUserRepo.convertReservationToFailure).toHaveBeenCalledTimes(1);
    expect(rateLimiter.recordAttempt).toHaveBeenCalledWith(
      'tenant-1', 'owner', validDto.ip, false, expect.any(Number),
    );
    expect(authUserRepo.update).not.toHaveBeenCalled();
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('returns a uniform rate-limit decision for a live lock and exposes no lock metadata', async () => {
    const lockedUntil = Date.now() + 60000;
    (authUserRepo.findByTenantAndUsername as ReturnType<typeof vi.fn>)
      .mockResolvedValue(authUser({ lockedUntil }));

    const result = await useCase.execute(validDto) as LoginResponse;

    expect(result).toMatchObject({ ok: false, error: 'RATE_LIMITED' });
    expect((result as { lockedUntil?: number }).lockedUntil).toBeUndefined();
    expect((result as { retryAfterMs?: number }).retryAfterMs).toBeGreaterThan(0);
    expect(authService.validateCredentials).toHaveBeenCalledWith(
      'correct-password',
      'hash',
    );
    expect(authUserRepo.releaseLoginAttempt).toHaveBeenCalledTimes(1);
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('pays the dummy KDF cost for an unknown username before returning BAD_CREDENTIALS', async () => {
    (authUserRepo.findByTenantAndUsername as ReturnType<typeof vi.fn>).mockResolvedValue(null);
    (authService.validateCredentials as ReturnType<typeof vi.fn>).mockResolvedValue(false);

    const result = await useCase.execute(validDto) as LoginResponse;

    expect(result).toMatchObject({ ok: false, error: 'BAD_CREDENTIALS' });
    expect(authService.validateCredentials).toHaveBeenCalledWith(
      'correct-password',
      DUMMY_HASH,
    );
  });

  it('mints a verifiable HS256 session JWT bound to the created session', async () => {
    const result = await useCase.execute(validDto);

    if (!result.ok) throw new Error('expected successful login');
    const claims = await verifySessionJwt(result.data.token, SECRET);
    expect(claims).toMatchObject({
      tid: 'tenant-1',
      usr: 'owner',
      role: 'admin',
      jti: result.data.sessionId,
    });
    expect(result.data.token.split('.')).toHaveLength(3);
    expect(sessionRepo.insert).toHaveBeenCalledWith(expect.objectContaining({
      source: 'web',
    }));
    const insertedSession = (sessionRepo.insert as ReturnType<typeof vi.fn>).mock.calls[0]?.[0];
    expect(insertedSession?.endedAt).toBeUndefined();
    expect(result.data.sessionId).toMatch(/^sess_[0-9a-f-]{36}$/);
  });

  it('generates distinct UUID-style web session and device ids', async () => {
    const first = await useCase.execute(validDto);
    const second = await useCase.execute(validDto);

    if (!first.ok || !second.ok) throw new Error('expected successful logins');
    const insertedSessions = (sessionRepo.insert as ReturnType<typeof vi.fn>)
      .mock.calls.map((call) => call[0]);

    expect(first.data.sessionId).toMatch(
      /^sess_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
    );
    expect(insertedSessions[0]?.deviceHwid).toMatch(
      /^web_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
    );
    expect(new Set([
      first.data.sessionId,
      second.data.sessionId,
      insertedSessions[0]?.deviceHwid,
      insertedSessions[1]?.deviceHwid,
    ]).size).toBe(4);
  });

  it('records a successful login outcome after resetting account failures', async () => {
    const result = await useCase.execute(validDto);

    expect(result.ok).toBe(true);
    expect(authUserRepo.resetFailures).toHaveBeenCalledTimes(1);
    expect(rateLimiter.recordAttempt).toHaveBeenCalledWith(
      'tenant-1', 'owner', validDto.ip, true, expect.any(Number),
    );
    expect(authUserRepo.releaseLoginAttempt).toHaveBeenCalledTimes(1);
  });

  it('preserves the existing owner email and requests timestamp-only persistence', async () => {
    const result = await useCase.execute(validDto);

    expect(result.ok).toBe(true);
    if (!result.ok) throw new Error('expected successful login');
    expect(userRepo.upsert).toHaveBeenCalledWith(expect.objectContaining({
      tenantId: 'tenant-1',
      email: 'owner@example.test',
      lastLoginAt: expect.any(Number),
      lastOwnerLoginAt: expect.any(Number),
    }));
    expect(result.data?.profile?.email).toBe('owner@example.test');
  });

  it('persists the admin role, display name, and both login timestamps', async () => {
    const result = await useCase.execute(validDto);

    if (!result.ok) throw new Error('expected successful login');
    const upsert = (userRepo.upsert as ReturnType<typeof vi.fn>).mock.calls[0]?.[0];
    const now = result.data.profile.lastLoginAt;
    expect(upsert).toMatchObject({
      tenantId: 'tenant-1',
      email: 'owner@example.test',
      role: 'admin',
      displayName: 'Owner',
      lastLoginAt: now,
      lastOwnerLoginAt: now,
    });
    expect(result.data.profile.lastLoginAt).toBe(now);
    expect(result.data.profile.lastOwnerLoginAt).toBe(now);
  });

  it('requires owner re-auth when the Stage-1 login is stale', async () => {
    (authService.shouldRequireOwnerReauth as ReturnType<typeof vi.fn>).mockReturnValue(true);

    const result = await useCase.execute(validDto) as LoginResponse;

    expect(result).toMatchObject({ ok: false, error: 'OWNER_REAUTH_REQUIRED' });
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('returns SESSION_CONFLICT for a fresh live web session instead of replacing it silently', async () => {
    (sessionRepo.getActiveForUsername as ReturnType<typeof vi.fn>).mockResolvedValue([
      { id: 'sess-live', tenantId: 'tenant-1' },
    ]);

    const result = await useCase.execute(validDto) as LoginResponse;

    expect(result).toMatchObject({
      ok: false,
      error: 'SESSION_CONFLICT',
      conflictSessionId: 'sess-live',
    });
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('returns the limiter decision without reserving or verifying credentials', async () => {
    (rateLimiter.checkLimit as ReturnType<typeof vi.fn>).mockResolvedValue({
      allowed: false,
      retryAfterMs: 1234,
    });

    const result = await useCase.execute(validDto) as LoginResponse;

    expect(result).toMatchObject({ ok: false, error: 'RATE_LIMITED', retryAfterMs: 1234 });
    expect(authUserRepo.reserveLoginAttempt).not.toHaveBeenCalled();
    expect(authService.validateCredentials).not.toHaveBeenCalled();
  });

  it('rejects a missing trusted IP before any authentication work', async () => {
    const result = await useCase.execute({ ...validDto, ip: '' }) as LoginResponse;

    expect(result).toMatchObject({ ok: false, error: 'MISSING_FIELDS' });
    expect(rateLimiter.checkLimit).not.toHaveBeenCalled();
  });
});
