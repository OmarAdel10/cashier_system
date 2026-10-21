/**
 * SyncFirebaseUserUseCase Tests
 *
 * Covers POST /auth/sync-user parity: an existing row is returned as-is; a
 * missing row falls back to the just-created profile shape WITHOUT writing.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SyncFirebaseUserUseCase } from '../sync-firebase-user-use-case';

const FIXED_NOW = 1_700_000_000_000;

const makeUser = () => ({
  tenantId: 'tenant-1',
  email: 'owner@test.com',
  role: 'admin',
  tier: 'pro',
  displayName: 'Owner',
  createdAt: FIXED_NOW - 86_400_000,
  lastLoginAt: FIXED_NOW - 5_000,
  lastOwnerLoginAt: FIXED_NOW - 100_000,
});

const makeLicense = () => ({
  tenantId: 'tenant-1',
  deviceHwid: 'device-1',
  licenseKey: 'key-1',
  subscriptionEnd: FIXED_NOW + 30 * 86_400_000,
  billingCycle: 'monthly' as const,
  graceEnd: FIXED_NOW + 37 * 86_400_000,
  status: 'active' as const,
  createdAt: FIXED_NOW - 86_400_000,
});

const makeUserRepo = (user: ReturnType<typeof makeUser> | null = makeUser()) => ({
  findByTenantId: vi.fn().mockResolvedValue(user),
  upsert: vi.fn().mockResolvedValue(undefined),
});

const makeLicenseRepo = (license: ReturnType<typeof makeLicense> | null = makeLicense()) => ({
  findLatestByTenant: vi.fn().mockResolvedValue(license),
});

describe('SyncFirebaseUserUseCase', () => {
  let userRepo: ReturnType<typeof makeUserRepo>;
  let licenseRepo: ReturnType<typeof makeLicenseRepo>;
  let useCase: SyncFirebaseUserUseCase;

  beforeEach(() => {
    userRepo = makeUserRepo();
    licenseRepo = makeLicenseRepo();
    useCase = new SyncFirebaseUserUseCase(userRepo as any, licenseRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('returns the existing profile and license without writing', async () => {
    const result = await useCase.execute({ tenantId: 'tenant-1', email: 'owner@test.com' });

    expect(userRepo.findByTenantId).toHaveBeenCalledWith('tenant-1');
    expect(licenseRepo.findLatestByTenant).toHaveBeenCalledWith('tenant-1');
    expect(userRepo.upsert).not.toHaveBeenCalled();
    expect(result).toEqual({
      ok: true,
      data: { profile: makeUser(), license: makeLicense() },
    });
  });

  it('prefers the stored row email over the token email', async () => {
    const result = await useCase.execute({ tenantId: 'tenant-1', email: 'token@mobile.com' });

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.profile.email).toBe('owner@test.com');
    }
  });

  it('falls back to the just-created profile shape when the row is missing', async () => {
    userRepo = makeUserRepo(null);
    useCase = new SyncFirebaseUserUseCase(userRepo as any, licenseRepo as any);

    const result = await useCase.execute({ tenantId: 'tenant-1', email: 'fresh@test.com' });

    expect(userRepo.upsert).not.toHaveBeenCalled();
    expect(result).toEqual({
      ok: true,
      data: {
        profile: {
          tenantId: 'tenant-1',
          email: 'fresh@test.com',
          role: 'admin',
          createdAt: FIXED_NOW,
        },
        license: makeLicense(),
      },
    });
  });

  it('falls back with an empty email when the token carried none', async () => {
    userRepo = makeUserRepo(null);
    useCase = new SyncFirebaseUserUseCase(userRepo as any, licenseRepo as any);

    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(result).toEqual({
      ok: true,
      data: {
        profile: {
          tenantId: 'tenant-1',
          email: '',
          role: 'admin',
          createdAt: FIXED_NOW,
        },
        license: makeLicense(),
      },
    });
  });

  it('passes a null license through', async () => {
    licenseRepo = makeLicenseRepo(null);
    useCase = new SyncFirebaseUserUseCase(userRepo as any, licenseRepo as any);

    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(result).toEqual({
      ok: true,
      data: { profile: makeUser(), license: null },
    });
  });

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    userRepo.findByTenantId.mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute({ tenantId: 'tenant-1' })).rejects.toThrow('db down');
  });

  it('uses post-read time for the fallback createdAt', async () => {
    userRepo.findByTenantId.mockImplementationOnce(async () => {
      vi.setSystemTime(FIXED_NOW + 5_000);
      return null;
    });

    const result = await useCase.execute({ tenantId: 'tenant-1', email: 'fresh@test.com' });

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.profile.createdAt).toBe(FIXED_NOW + 5_000);
    }
  });

  it('propagates license lookup rejections instead of resolving an error arm', async () => {
    licenseRepo.findLatestByTenant.mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute({ tenantId: 'tenant-1' })).rejects.toThrow('db down');
  });
});
