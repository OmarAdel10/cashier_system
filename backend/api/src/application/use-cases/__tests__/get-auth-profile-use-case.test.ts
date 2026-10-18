/**
 * GetAuthProfileUseCase Tests
 *
 * Covers /auth/me parity: profile + license are passed through and both
 * nullable (a missing row is still ok with null, never an error).
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { GetAuthProfileUseCase } from '../get-auth-profile-use-case';

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

const makeLicense = (overrides: Partial<{ graceEnd: number; status: 'active' | 'expired' }> = {}) => ({
  tenantId: 'tenant-1',
  deviceHwid: 'device-1',
  licenseKey: 'key-1',
  subscriptionEnd: FIXED_NOW + 30 * 86_400_000,
  billingCycle: 'monthly' as const,
  graceEnd: overrides.graceEnd ?? FIXED_NOW + 37 * 86_400_000,
  status: overrides.status ?? ('active' as const),
  createdAt: FIXED_NOW - 86_400_000,
});

const makeUserRepo = (user: ReturnType<typeof makeUser> | null = makeUser()) => ({
  findByTenantId: vi.fn().mockResolvedValue(user),
});

const makeLicenseRepo = (license: ReturnType<typeof makeLicense> | null = makeLicense()) => ({
  findLatestByTenant: vi.fn().mockResolvedValue(license),
});

describe('GetAuthProfileUseCase', () => {
  let userRepo: ReturnType<typeof makeUserRepo>;
  let licenseRepo: ReturnType<typeof makeLicenseRepo>;
  let useCase: GetAuthProfileUseCase;

  beforeEach(() => {
    userRepo = makeUserRepo();
    licenseRepo = makeLicenseRepo();
    useCase = new GetAuthProfileUseCase(userRepo as any, licenseRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('passes profile and license through', async () => {
    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(userRepo.findByTenantId).toHaveBeenCalledWith('tenant-1');
    expect(licenseRepo.findLatestByTenant).toHaveBeenCalledWith('tenant-1');
    expect(result).toEqual({
      ok: true,
      data: { profile: makeUser(), license: makeLicense() },
    });
  });

  it('returns ok with a null profile when the user row is missing', async () => {
    userRepo = makeUserRepo(null);
    useCase = new GetAuthProfileUseCase(userRepo as any, licenseRepo as any);

    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(result).toEqual({
      ok: true,
      data: { profile: null, license: makeLicense() },
    });
  });

  it('returns ok with a null license when none exists', async () => {
    licenseRepo = makeLicenseRepo(null);
    useCase = new GetAuthProfileUseCase(userRepo as any, licenseRepo as any);

    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(result).toEqual({
      ok: true,
      data: { profile: makeUser(), license: null },
    });
  });

  it('returns ok with both null when neither row exists', async () => {
    userRepo = makeUserRepo(null);
    licenseRepo = makeLicenseRepo(null);
    useCase = new GetAuthProfileUseCase(userRepo as any, licenseRepo as any);

    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(result).toEqual({
      ok: true,
      data: { profile: null, license: null },
    });
  });

  it('passes an expired license through unchanged', async () => {
    const expiredLicense = makeLicense({ graceEnd: FIXED_NOW - 1, status: 'expired' });
    licenseRepo = makeLicenseRepo(expiredLicense);
    useCase = new GetAuthProfileUseCase(userRepo as any, licenseRepo as any);

    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(result).toEqual({
      ok: true,
      data: { profile: makeUser(), license: expiredLicense },
    });
  });
});
