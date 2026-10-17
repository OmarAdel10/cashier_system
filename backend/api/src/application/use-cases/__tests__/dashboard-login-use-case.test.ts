/**
 * DashboardLoginUseCase Tests
 *
 * Covers all branches of the dashboard login flow:
 * input validation, rate limiting, reservation, KDF, lockout,
 * admin-only gate, owner re-auth, session conflict, and success path.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { DashboardLoginUseCase } from '../dashboard-login-use-case';
import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { AuthService } from 'daftari-backend-shared/domain/services/auth-service';
import type { RateLimiter } from 'daftari-backend-shared/domain/services/rate-limiter';
import type { SessionTokenService } from 'daftari-backend-shared/application/services/session-token-service';
import { DUMMY_HASH } from 'daftari-backend-shared/password_kdf';

const JWT_SECRET = 'test-jwt-secret';
const FIXED_NOW = 1_700_000_000_000;

const baseDto = {
  tenantId: 'tenant-1',
  username: 'admin',
  password: 'password123',
  ip: '127.0.0.1',
};

const makeAuthUser = (overrides: Partial<{
  passwordHash: string;
  isActive: number;
  role: 'admin' | 'cashier';
  lockedUntil: number | undefined;
}> = {}) => ({
  tenantId: 'tenant-1',
  username: 'admin',
  passwordHash: overrides.passwordHash ?? 'pbkdf2-sha512$1000000$salt$hash',
  role: overrides.role ?? 'admin',
  displayName: 'Admin User',
  mustChangePassword: 0,
  isActive: overrides.isActive ?? 1,
  failedAttempts: 0,
  lockedUntil: overrides.lockedUntil ?? undefined,
  createdAt: FIXED_NOW - 86400000,
  updatedAt: FIXED_NOW - 86400000,
});

const makeOwner = (overrides: Partial<{
  lastOwnerLoginAt: number | undefined;
}> = {}) => ({
  tenantId: 'tenant-1',
  email: 'owner@test.com',
  role: 'admin',
  tier: 'pro',
  displayName: 'Owner',
  createdAt: FIXED_NOW - 86400000,
  lastOwnerLoginAt: overrides.lastOwnerLoginAt ?? FIXED_NOW - 1000,
});

const makeAuthUserRepo = (overrides: Partial<{
  reserveLoginAttempt: boolean;
  findByTenantAndUsername: ReturnType<typeof makeAuthUser> | null;
}> = {}) => ({
  reserveLoginAttempt: vi.fn().mockResolvedValue(overrides.reserveLoginAttempt ?? true),
  releaseLoginAttempt: vi.fn().mockResolvedValue(undefined),
  convertReservationToFailure: vi.fn().mockResolvedValue(undefined),
  findByTenantAndUsername: vi.fn().mockResolvedValue(overrides.findByTenantAndUsername ?? null),
  recordFailure: vi.fn().mockResolvedValue(undefined),
  resetFailures: vi.fn().mockResolvedValue(undefined),
});

const makeSessionRepo = (overrides: Partial<{
  getActiveForUsername: ReturnType<typeof vi.fn>['mockResolvedValue'] extends infer T ? T : never;
  insert: boolean;
}> = {}) => ({
  getActiveForUsername: vi.fn().mockResolvedValue(overrides.getActiveForUsername ?? []),
  endWebSessions: vi.fn().mockResolvedValue(undefined),
  insert: vi.fn().mockResolvedValue(overrides.insert ?? true),
});

const makeRateLimiter = (overrides: Partial<{
  checkLimit: { allowed: boolean; retryAfterMs: number };
}> = {}) => ({
  checkLimit: vi.fn().mockResolvedValue(overrides.checkLimit ?? { allowed: true, retryAfterMs: 0 }),
  recordAttempt: vi.fn().mockResolvedValue(undefined),
});

const makeTokenService = () => ({
  mint: vi.fn().mockResolvedValue('mock-token'),
});

const makeUserRepo = (overrides: Partial<{
  findByTenantId: ReturnType<typeof makeOwner>;
}> = {}) => ({
  findByTenantId: vi.fn().mockResolvedValue(overrides.findByTenantId ?? makeOwner()),
});

const makePasswordVerifier = (result: boolean) => vi.fn().mockResolvedValue(result);

describe('DashboardLoginUseCase', () => {
  let authUserRepo: ReturnType<typeof makeAuthUserRepo>;
  let sessionRepo: ReturnType<typeof makeSessionRepo>;
  let rateLimiter: ReturnType<typeof makeRateLimiter>;
  let tokenService: ReturnType<typeof makeTokenService>;
  let userRepo: ReturnType<typeof makeUserRepo>;
  let passwordVerifier: ReturnType<typeof makePasswordVerifier>;
  let useCase: DashboardLoginUseCase;

  beforeEach(() => {
    authUserRepo = makeAuthUserRepo();
    sessionRepo = makeSessionRepo();
    rateLimiter = makeRateLimiter();
    tokenService = makeTokenService();
    userRepo = makeUserRepo();
    passwordVerifier = makePasswordVerifier(true);
    useCase = new DashboardLoginUseCase(
      authUserRepo as any,
      sessionRepo as any,
      {} as any,
      userRepo as any,
      {} as any,
      rateLimiter as any,
      tokenService as any,
      JWT_SECRET,
      passwordVerifier,
    );
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  const execute = (dto = baseDto) => useCase.execute(dto as any);

  describe('input validation', () => {
    it('returns MISSING_FIELDS when tenantId is empty', async () => {
      const result = await execute({ ...baseDto, tenantId: '' });
      expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS', retryAfterMs: 0 });
    });

    it('returns MISSING_FIELDS when username is whitespace-only', async () => {
      const result = await execute({ ...baseDto, username: '   ' });
      expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS', retryAfterMs: 0 });
    });

    it('returns MISSING_FIELDS when password is empty', async () => {
      const result = await execute({ ...baseDto, password: '' });
      expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS', retryAfterMs: 0 });
    });

    it('returns MISSING_FIELDS when ip is empty', async () => {
      const result = await execute({ ...baseDto, ip: '' });
      expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS', retryAfterMs: 0 });
    });

    it('does not call rate limiter when fields are missing', async () => {
      await execute({ ...baseDto, tenantId: '' });
      expect(rateLimiter.checkLimit).not.toHaveBeenCalled();
    });
  });

  describe('rate limiting', () => {
    it('returns RATE_LIMITED when checkLimit denies', async () => {
      rateLimiter.checkLimit = vi.fn().mockResolvedValue({ allowed: false, retryAfterMs: 1000 });
      const result = await execute();
      expect(result).toEqual({ ok: false, error: 'RATE_LIMITED', retryAfterMs: 1000 });
    });

    it('returns RATE_LIMITED when reservation fails', async () => {
      authUserRepo.reserveLoginAttempt = vi.fn().mockResolvedValue(false);
      const result = await execute();
      expect(result).toEqual({ ok: false, error: 'RATE_LIMITED', retryAfterMs: 0 });
    });

    it('records a failed attempt before KDF', async () => {
      await execute();
      expect(rateLimiter.recordAttempt).toHaveBeenCalledWith(
        'tenant-1', 'admin', '127.0.0.1', false, FIXED_NOW,
      );
    });
  });

  describe('KDF and credential validation', () => {
    it('runs KDF with DUMMY_HASH for unknown user', async () => {
      await execute();
      expect(passwordVerifier).toHaveBeenCalledWith(DUMMY_HASH, 'password123');
    });

    it('returns BAD_CREDENTIALS when user not found', async () => {
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(null);
      const result = await execute();
      expect(result).toEqual({ ok: false, error: 'BAD_CREDENTIALS', retryAfterMs: 0 });
    });

    it('returns BAD_CREDENTIALS when password is wrong', async () => {
      passwordVerifier = makePasswordVerifier(false);
      // Need to reconstruct use case with new verifier
      useCase = new DashboardLoginUseCase(
        authUserRepo as any, sessionRepo as any, {} as any, userRepo as any,
        {} as any, rateLimiter as any, tokenService as any, JWT_SECRET, passwordVerifier,
      );
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(makeAuthUser());
      const result = await execute();
      expect(result).toEqual({ ok: false, error: 'BAD_CREDENTIALS', retryAfterMs: 0 });
    });

    it('converts reservation to failure on bad credentials', async () => {
      const authUser = makeAuthUser();
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(authUser);
      passwordVerifier = makePasswordVerifier(false);
      useCase = new DashboardLoginUseCase(
        authUserRepo as any, sessionRepo as any, {} as any, userRepo as any,
        {} as any, rateLimiter as any, tokenService as any, JWT_SECRET, passwordVerifier,
      );
      await execute();
      expect(authUserRepo.convertReservationToFailure).toHaveBeenCalledWith('tenant-1', 'admin');
    });
  });

  describe('lockout', () => {
    it('returns RATE_LIMITED when account is locked', async () => {
      const authUser = makeAuthUser({ lockedUntil: FIXED_NOW + 3600000 });
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(authUser);
      const result = await execute();
      expect(result.ok).toBe(false);
      const errorResult = result as { ok: false; error: string; retryAfterMs: number };
      expect(errorResult.error).toBe('RATE_LIMITED');
      expect(errorResult.retryAfterMs).toBeGreaterThan(0);
    });

    it('calls resetFailures when lock window has elapsed', async () => {
      const authUser = makeAuthUser({ lockedUntil: FIXED_NOW - 1000 });
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(authUser);
      passwordVerifier = makePasswordVerifier(true);
      useCase = new DashboardLoginUseCase(
        authUserRepo as any, sessionRepo as any, {} as any, userRepo as any,
        {} as any, rateLimiter as any, tokenService as any, JWT_SECRET, passwordVerifier,
      );
      await execute();
      expect(authUserRepo.resetFailures).toHaveBeenCalledWith('tenant-1', 'admin');
    });
  });

  describe('admin-only gate', () => {
    it('returns DASHBOARD_ADMIN_ONLY when role is cashier', async () => {
      const authUser = makeAuthUser({ role: 'cashier' });
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(authUser);
      const result = await execute();
      expect(result).toEqual({ ok: false, error: 'DASHBOARD_ADMIN_ONLY', retryAfterMs: 0 });
    });
  });

  describe('owner re-auth gate', () => {
    it('returns OWNER_REAUTH_REQUIRED when owner last login is stale', async () => {
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(makeAuthUser());
      userRepo.findByTenantId = vi.fn().mockResolvedValue(makeOwner({ lastOwnerLoginAt: FIXED_NOW - 200 * 24 * 3600 * 1000 }));
      const result = await execute();
      expect(result).toEqual({ ok: false, error: 'OWNER_REAUTH_REQUIRED', retryAfterMs: 0 });
    });

    it('allows login when owner re-auth is fresh', async () => {
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(makeAuthUser());
      userRepo.findByTenantId = vi.fn().mockResolvedValue(makeOwner({ lastOwnerLoginAt: FIXED_NOW - 1000 }));
      const result = await execute();
      expect(result.ok).toBe(true);
    });
  });

  describe('session conflict', () => {
    it('returns SESSION_CONFLICT when active web session exists', async () => {
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(makeAuthUser());
      sessionRepo.getActiveForUsername = vi.fn().mockResolvedValue([{ id: 'sess-1', tenantId: 'tenant-1', username: 'admin' } as any]);
      const result = await execute();
      expect(result).toEqual({ ok: false, error: 'SESSION_CONFLICT', conflictSessionId: 'sess-1' });
    });

    it('returns SESSION_CONFLICT when session insert fails', async () => {
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(makeAuthUser());
      sessionRepo.insert = vi.fn().mockResolvedValue(false);
      const result = await execute();
      expect(result).toEqual({ ok: false, error: 'SESSION_CONFLICT', retryAfterMs: 0 });
    });
  });

  describe('success path', () => {
    it('returns ok with token and profile on successful login', async () => {
      const authUser = makeAuthUser();
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(authUser);
      const owner = makeOwner();
      userRepo.findByTenantId = vi.fn().mockResolvedValue(owner);

      const result = await execute();

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.data.token).toBe('mock-token');
        expect(result.data.sessionId).toMatch(/^sess_/);
        expect(result.data.profile).toEqual({
          tenantId: 'tenant-1',
          email: 'owner@test.com',
          role: 'admin',
          tier: 'pro',
          displayName: 'Owner',
          createdAt: owner.createdAt,
          lastLoginAt: FIXED_NOW,
          lastOwnerLoginAt: FIXED_NOW,
        });
      }
    });

    it('mints token with correct claims', async () => {
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(makeAuthUser());
      userRepo.findByTenantId = vi.fn().mockResolvedValue(makeOwner());
      await execute();
      expect(tokenService.mint).toHaveBeenCalledWith(
        expect.objectContaining({
          tid: 'tenant-1',
          usr: 'admin',
          role: 'admin',
          jti: expect.stringMatching(/^sess_/),
        }),
        JWT_SECRET,
      );
    });

    it('calls resetFailures and endWebSessions on success', async () => {
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(makeAuthUser());
      userRepo.findByTenantId = vi.fn().mockResolvedValue(makeOwner());
      await execute();
      expect(authUserRepo.resetFailures).toHaveBeenCalledWith('tenant-1', 'admin');
      expect(sessionRepo.endWebSessions).toHaveBeenCalledWith('tenant-1', 'admin', FIXED_NOW);
    });

    it('records successful attempt on success path', async () => {
      authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(makeAuthUser());
      userRepo.findByTenantId = vi.fn().mockResolvedValue(makeOwner());
      await execute();
      expect(rateLimiter.recordAttempt).toHaveBeenCalledWith(
        'tenant-1', 'admin', '127.0.0.1', true, FIXED_NOW,
      );
    });
  });
});
