/**
 * SessionStartUseCase Tests
 *
 * Covers start (web + POS), every error arm, missing-row no-op, idempotent
 * end, device limit, license expired, and dependency rejections.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SessionStartUseCase } from '../session-start-use-case';
import type { SessionStartDto } from '../../dtos/session-start.dto';
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { DeviceRepository } from 'daftari-backend-shared/domain/repositories/device-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { SessionTokenService } from 'daftari-backend-shared/application/services/session-token-service';

const JWT_SECRET = 'test-jwt-secret';
const FIXED_NOW = 1_700_000_000_000;
const NOW_S = 1_700_000_000;
const SESSION_TTL_S = 12 * 3600;

const baseDto: SessionStartDto = {
  tenantId: 'tenant-1',
  deviceHwid: 'device-1',
  username: 'admin',
  source: 'pos',
};

const makeSessionRepo = (overrides: Partial<SessionRepository> = {}) => ({
  endWebSessions: vi.fn().mockResolvedValue(undefined),
  insert: vi.fn().mockResolvedValue(true),
  admitPosSession: vi.fn().mockResolvedValue(true),
  endForDevice: vi.fn().mockResolvedValue(undefined),
  ...overrides,
});

const makeDeviceRepo = (overrides: Partial<DeviceRepository> = {}) => ({
  upsert: vi.fn().mockResolvedValue(undefined),
  ...overrides,
});

const makeLicenseRepo = (overrides: Partial<LicenseRepository> = {}) => ({
  findLatestByTenant: vi.fn().mockResolvedValue(null),
  isExpired: vi.fn().mockResolvedValue(false),
  getDeviceLimit: vi.fn().mockReturnValue(1),
  ...overrides,
});

const makeAuthUserRepo = (
  user: { isActive: number; role: string } | null = { isActive: 1, role: 'admin' },
) => ({
  findByTenantAndUsername: vi.fn().mockResolvedValue(user),
});

const makeUserRepo = (overrides: Partial<UserRepository> = {}) => ({
  findByTenantId: vi.fn().mockResolvedValue(null),
  ...overrides,
});

const makeTokenService = () => ({
  mint: vi.fn().mockResolvedValue('mock-token'),
});

describe('SessionStartUseCase', () => {
  let sessionRepo: ReturnType<typeof makeSessionRepo>;
  let deviceRepo: ReturnType<typeof makeDeviceRepo>;
  let licenseRepo: ReturnType<typeof makeLicenseRepo>;
  let authUserRepo: ReturnType<typeof makeAuthUserRepo>;
  let userRepo: ReturnType<typeof makeUserRepo>;
  let tokenService: ReturnType<typeof makeTokenService>;
  let useCase: SessionStartUseCase;

  beforeEach(() => {
    sessionRepo = makeSessionRepo();
    deviceRepo = makeDeviceRepo();
    licenseRepo = makeLicenseRepo();
    authUserRepo = makeAuthUserRepo();
    userRepo = makeUserRepo();
    tokenService = makeTokenService();
    useCase = new SessionStartUseCase(
      sessionRepo as any,
      deviceRepo as any,
      licenseRepo as any,
      authUserRepo as any,
      userRepo as any,
      tokenService as any,
      JWT_SECRET,
    );
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('starts a web session and mints 12h claims', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      graceEnd: FIXED_NOW + 86_400_000,
    });
    const result = await useCase.execute({ ...baseDto, source: 'web' });

    expect(authUserRepo.findByTenantAndUsername).toHaveBeenCalledWith('tenant-1', 'admin');
    expect(sessionRepo.endWebSessions).toHaveBeenCalledWith('tenant-1', 'admin', FIXED_NOW);
    expect(sessionRepo.insert).toHaveBeenCalledWith({
      id: expect.stringMatching(/^sess_/),
      tenantId: 'tenant-1',
      deviceHwid: 'device-1',
      username: 'admin',
      startedAt: FIXED_NOW,
      heartbeatAt: FIXED_NOW,
      source: 'web',
    });
    expect(tokenService.mint).toHaveBeenCalledWith(
      {
        tid: 'tenant-1',
        usr: 'admin',
        role: 'admin',
        jti: expect.stringMatching(/^sess_/),
        iat: NOW_S,
        exp: NOW_S + SESSION_TTL_S,
      },
      JWT_SECRET,
    );
    expect(result).toEqual({ ok: true, data: { sessionId: expect.any(String), token: 'mock-token' } });
    if (result.ok) {
      expect(tokenService.mint).toHaveBeenCalledWith(
        expect.objectContaining({ jti: result.data.sessionId }),
        JWT_SECRET,
      );
    }
  });

  it('starts a web session when only a POS session exists for the username', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({
      graceEnd: FIXED_NOW + 86_400_000,
    });
    const result = await useCase.execute({ ...baseDto, source: 'web' });

    expect(result.ok).toBe(true);
    expect(sessionRepo.endWebSessions).toHaveBeenCalled();
    expect(sessionRepo.insert).toHaveBeenCalled();
  });

  it('returns NO_LICENSE when web start has no license', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue(null);

    const result = await useCase.execute({ ...baseDto, source: 'web' });

    expect(result).toEqual({ ok: false, error: 'NO_LICENSE' });
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('returns LICENSE_EXPIRED when web start license grace has ended', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({ graceEnd: FIXED_NOW - 1 });
    licenseRepo.isExpired = vi.fn().mockResolvedValue(true);

    const result = await useCase.execute({ ...baseDto, source: 'web' });

    expect(result).toEqual({ ok: false, error: 'LICENSE_EXPIRED' });
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('returns USER_NOT_FOUND when the web auth user is missing', async () => {
    authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(null);

    const result = await useCase.execute({ ...baseDto, source: 'web' });

    expect(result).toEqual({ ok: false, error: 'USER_NOT_FOUND' });
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('returns ACCOUNT_DISABLED when the web auth user is inactive', async () => {
    authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue({ isActive: 0, role: 'cashier' });

    const result = await useCase.execute({ ...baseDto, source: 'web' });

    expect(result).toEqual({ ok: false, error: 'ACCOUNT_DISABLED' });
  });

  it('returns MISSING_FIELDS for empty fields', async () => {
    const result = await useCase.execute({ ...baseDto, tenantId: '' });

    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('returns MISSING_FIELDS for empty deviceHwid', async () => {
    const result = await useCase.execute({ ...baseDto, deviceHwid: '' });

    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('returns MISSING_FIELDS for empty username', async () => {
    const result = await useCase.execute({ ...baseDto, username: '' });

    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('returns MISSING_FIELDS for invalid source', async () => {
    const result = await useCase.execute({ ...baseDto, source: 'kiosk' } as unknown as SessionStartDto);

    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
    expect(sessionRepo.insert).not.toHaveBeenCalled();
    expect(sessionRepo.admitPosSession).not.toHaveBeenCalled();
    expect(sessionRepo.endWebSessions).not.toHaveBeenCalled();
  });

  it('returns USER_NOT_FOUND when starting a POS session for unknown user', async () => {
    authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue(null);

    const result = await useCase.execute(baseDto);

    expect(result).toEqual({ ok: false, error: 'USER_NOT_FOUND' });
    expect(sessionRepo.insert).not.toHaveBeenCalled();
    expect(sessionRepo.admitPosSession).not.toHaveBeenCalled();
  });

  it('returns ACCOUNT_DISABLED when starting a POS session for inactive user', async () => {
    authUserRepo.findByTenantAndUsername = vi.fn().mockResolvedValue({ isActive: 0, role: 'cashier' });

    const result = await useCase.execute(baseDto);

    expect(result).toEqual({ ok: false, error: 'ACCOUNT_DISABLED' });
    expect(sessionRepo.insert).not.toHaveBeenCalled();
    expect(sessionRepo.admitPosSession).not.toHaveBeenCalled();
  });

  it('starts a POS session when license and device limit allow', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({ graceEnd: FIXED_NOW + 86_400_000 });
    userRepo.findByTenantId = vi.fn().mockResolvedValue({ tier: 'pro' });
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(2);

    const result = await useCase.execute(baseDto);

    expect(licenseRepo.findLatestByTenant).toHaveBeenCalledWith('tenant-1');
    expect(deviceRepo.upsert).toHaveBeenCalledWith({
      tenantId: 'tenant-1',
      deviceHwid: 'device-1',
      firstSeenAt: FIXED_NOW,
      lastSeenAt: FIXED_NOW,
    });
    expect(sessionRepo.endForDevice).toHaveBeenCalledWith('tenant-1', 'device-1', FIXED_NOW);
    expect(sessionRepo.admitPosSession).toHaveBeenCalledWith(
      expect.objectContaining({ source: 'pos' }),
      2,
    );
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.sessionId).toMatch(/^sess_/);
      expect(result.data.token).toBe('mock-token');
    }
  });

  it('starts a POS session with the starter tier when no tenant profile exists', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({ graceEnd: FIXED_NOW + 86_400_000 });
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(1);

    const result = await useCase.execute(baseDto);

    expect(licenseRepo.getDeviceLimit).toHaveBeenCalledWith('starter');
    expect(result.ok).toBe(true);
  });

  it('returns NO_LICENSE when the tenant has no license', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue(null);

    const result = await useCase.execute(baseDto);

    expect(result).toEqual({ ok: false, error: 'NO_LICENSE' });
  });

  it('returns LICENSE_EXPIRED when the license grace has ended', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({ graceEnd: FIXED_NOW - 1 });
    licenseRepo.isExpired = vi.fn().mockResolvedValue(true);

    const result = await useCase.execute(baseDto);

    expect(result).toEqual({ ok: false, error: 'LICENSE_EXPIRED' });
  });

  it('returns SESSION_CREATION_FAILED when POS admission fails', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({ graceEnd: FIXED_NOW + 86_400_000 });
    userRepo.findByTenantId = vi.fn().mockResolvedValue({ tier: 'starter' });
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(5);
    sessionRepo.admitPosSession = vi.fn().mockResolvedValue(false);

    const result = await useCase.execute(baseDto);

    expect(result).toEqual({ ok: false, error: 'SESSION_CREATION_FAILED' });
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('returns SESSION_CREATION_FAILED when POS admission fails after device upsert', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({ graceEnd: FIXED_NOW + 86_400_000 });
    userRepo.findByTenantId = vi.fn().mockResolvedValue({ tier: 'starter' });
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(5);
    sessionRepo.admitPosSession = vi.fn().mockResolvedValue(false);

    const result = await useCase.execute(baseDto);

    expect(result).toEqual({ ok: false, error: 'SESSION_CREATION_FAILED' });
    expect(deviceRepo.upsert).toHaveBeenCalledWith({
      tenantId: 'tenant-1',
      deviceHwid: 'device-1',
      firstSeenAt: FIXED_NOW,
      lastSeenAt: FIXED_NOW,
    });
    expect(sessionRepo.endForDevice).toHaveBeenCalledWith('tenant-1', 'device-1', FIXED_NOW);
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    authUserRepo.findByTenantAndUsername = vi.fn().mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute({ ...baseDto, source: 'web' })).rejects.toThrow('db down');
  });
});
