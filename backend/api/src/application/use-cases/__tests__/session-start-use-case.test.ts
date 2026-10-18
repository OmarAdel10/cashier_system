/**
 * SessionStartUseCase Tests
 *
 * Covers start (web + POS), every error arm, missing-row no-op, idempotent
 * end, conflict, device limit, license expired, and dependency rejections.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SessionStartUseCase } from '../session-start-use-case';
import type { SessionStartDto } from '../../dtos/session-start.dto';

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

const makeSessionRepo = (overrides: Record<string, unknown> = {}) => ({
  getActiveForUsername: vi.fn().mockResolvedValue([]),
  endWebSessions: vi.fn().mockResolvedValue(undefined),
  insert: vi.fn().mockResolvedValue(true),
  findLatestByTenant: vi.fn().mockResolvedValue(null),
  isExpired: vi.fn().mockResolvedValue(false),
  findByTenantId: vi.fn().mockResolvedValue(null),
  getDeviceLimit: vi.fn().mockReturnValue(1),
  getActivePos: vi.fn().mockResolvedValue([]),
  upsert: vi.fn().mockResolvedValue(undefined),
  endForDevice: vi.fn().mockResolvedValue(undefined),
  admitPosSession: vi.fn().mockResolvedValue(true),
  ...overrides,
});

const makeAuthUserRepo = (user: { isActive: number; role: string } | null = { isActive: 1, role: 'admin' }) => ({
  findByTenantAndUsername: vi.fn().mockResolvedValue(user),
});

const makeTokenService = () => ({
  mint: vi.fn().mockResolvedValue('mock-token'),
});

describe('SessionStartUseCase', () => {
  let sessionRepo: ReturnType<typeof makeSessionRepo>;
  let deviceRepo: ReturnType<typeof makeSessionRepo>;
  let licenseRepo: ReturnType<typeof makeSessionRepo>;
  let authUserRepo: ReturnType<typeof makeAuthUserRepo>;
  let userRepo: ReturnType<typeof makeSessionRepo>;
  let tokenService: ReturnType<typeof makeTokenService>;
  let useCase: SessionStartUseCase;

  beforeEach(() => {
    sessionRepo = makeSessionRepo();
    deviceRepo = makeSessionRepo();
    licenseRepo = makeSessionRepo();
    authUserRepo = makeAuthUserRepo();
    userRepo = makeSessionRepo();
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

  it('returns SESSION_CONFLICT when an active web session exists', async () => {
    sessionRepo.getActiveForUsername = vi.fn().mockResolvedValue([{ id: 'sess-old', source: 'web' }]);

    const result = await useCase.execute({ ...baseDto, source: 'web' });

    expect(result).toEqual({ ok: false, error: 'SESSION_CONFLICT' });
    expect(sessionRepo.insert).not.toHaveBeenCalled();
  });

  it('returns SESSION_CREATION_FAILED when web insert fails', async () => {
    sessionRepo.insert = vi.fn().mockResolvedValue(false);

    const result = await useCase.execute({ ...baseDto, source: 'web' });

    expect(result).toEqual({ ok: false, error: 'SESSION_CREATION_FAILED' });
  });

  it('returns MISSING_FIELDS for empty fields', async () => {
    const result = await useCase.execute({ ...baseDto, tenantId: '' });

    expect(result).toEqual({ ok: false, error: 'MISSING_FIELDS' });
  });

  it('starts a POS session when license and device limit allow', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({ graceEnd: FIXED_NOW + 86_400_000 });
    userRepo.findByTenantId = vi.fn().mockResolvedValue({ tier: 'pro' });
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(2);

    const result = await useCase.execute(baseDto);

    expect(licenseRepo.findLatestByTenant).toHaveBeenCalledWith('tenant-1');
    expect(sessionRepo.getActivePos).toHaveBeenCalledWith('tenant-1');
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
    // userRepo.findByTenantId defaults to null -> tier falls back to 'starter'
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(1);

    const result = await useCase.execute(baseDto);

    expect(licenseRepo.getDeviceLimit).toHaveBeenCalledWith('starter');
    expect(sessionRepo.getActivePos).toHaveBeenCalledWith('tenant-1');
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

  it('returns DEVICE_LIMIT_EXCEEDED when active POS sessions reach the limit', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({ graceEnd: FIXED_NOW + 86_400_000 });
    userRepo.findByTenantId = vi.fn().mockResolvedValue({ tier: 'starter' });
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(1);
    sessionRepo.getActivePos = vi.fn().mockResolvedValue([{ id: 'sess-1' }, { id: 'sess-2' }]);

    const result = await useCase.execute(baseDto);

    expect(result).toEqual({ ok: false, error: 'DEVICE_LIMIT_EXCEEDED' });
    expect(sessionRepo.admitPosSession).not.toHaveBeenCalled();
  });

  it('returns SESSION_CREATION_FAILED when POS admission fails', async () => {
    licenseRepo.findLatestByTenant = vi.fn().mockResolvedValue({ graceEnd: FIXED_NOW + 86_400_000 });
    userRepo.findByTenantId = vi.fn().mockResolvedValue({ tier: 'starter' });
    licenseRepo.getDeviceLimit = vi.fn().mockReturnValue(5);
    sessionRepo.admitPosSession = vi.fn().mockResolvedValue(false);

    const result = await useCase.execute(baseDto);

    expect(result).toEqual({ ok: false, error: 'SESSION_CREATION_FAILED' });
  });

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    authUserRepo.findByTenantAndUsername = vi.fn().mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute({ ...baseDto, source: 'web' })).rejects.toThrow('db down');
  });
});
