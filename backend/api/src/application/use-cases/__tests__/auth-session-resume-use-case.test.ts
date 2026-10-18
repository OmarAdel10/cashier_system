/**
 * AuthSessionResumeUseCase Tests
 *
 * Covers the resume path: the SAME session id is re-minted with fresh claims
 * (12h TTL) and the tenant profile is passed through, including the null case.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { AuthSessionResumeUseCase } from '../auth-session-resume-use-case';

const JWT_SECRET = 'test-jwt-secret';
const FIXED_NOW = 1_700_000_000_000;
const NOW_S = 1_700_000_000;
const SESSION_TTL_S = 12 * 3600;

const baseDto = {
  sessionId: 'sess-1',
  tenantId: 'tenant-1',
  username: 'admin',
  role: 'admin',
};

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

const makeUserRepo = (user: ReturnType<typeof makeUser> | null = makeUser()) => ({
  findByTenantId: vi.fn().mockResolvedValue(user),
});

const makeTokenService = () => ({
  mint: vi.fn().mockResolvedValue('mock-token'),
});

describe('AuthSessionResumeUseCase', () => {
  let tokenService: ReturnType<typeof makeTokenService>;
  let userRepo: ReturnType<typeof makeUserRepo>;
  let useCase: AuthSessionResumeUseCase;

  beforeEach(() => {
    tokenService = makeTokenService();
    userRepo = makeUserRepo();
    useCase = new AuthSessionResumeUseCase(tokenService as any, userRepo as any, JWT_SECRET);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('re-mints the same session id with fresh 12h claims', async () => {
    const result = await useCase.execute(baseDto);

    expect(tokenService.mint).toHaveBeenCalledWith(
      {
        tid: 'tenant-1',
        usr: 'admin',
        role: 'admin',
        jti: 'sess-1',
        iat: NOW_S,
        exp: NOW_S + SESSION_TTL_S,
      },
      JWT_SECRET,
    );
    expect(result).toEqual({
      ok: true,
      data: {
        token: 'mock-token',
        sessionId: 'sess-1',
        profile: makeUser(),
      },
    });
  });

  it('floors sub-second timestamps into the JWT claims', async () => {
    vi.setSystemTime(new Date(1_700_000_000_999));

    await useCase.execute(baseDto);

    expect(tokenService.mint).toHaveBeenCalledWith(
      {
        tid: 'tenant-1',
        usr: 'admin',
        role: 'admin',
        jti: 'sess-1',
        iat: 1_700_000_000,
        exp: 1_700_000_000 + 43_200,
      },
      JWT_SECRET,
    );
  });

  it('passes the repo profile through unchanged', async () => {
    const profile = {
      ...makeUser(),
      email: 'custom@test.com',
      role: 'cashier',
    };
    userRepo.findByTenantId = vi.fn().mockResolvedValue(profile);

    const result = await useCase.execute({ ...baseDto, role: 'cashier' });

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.profile).toEqual(profile);
    }
    expect(tokenService.mint).toHaveBeenCalledWith(
      expect.objectContaining({ role: 'cashier' }),
      JWT_SECRET,
    );
  });

  it('supports a null profile when the user row is missing', async () => {
    userRepo.findByTenantId = vi.fn().mockResolvedValue(null);

    const result = await useCase.execute(baseDto);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.profile).toBeNull();
    }
    expect(result).toEqual({
      ok: true,
      data: {
        token: 'mock-token',
        sessionId: 'sess-1',
        profile: null,
      },
    });
    expect(userRepo.findByTenantId).toHaveBeenCalledWith('tenant-1');
  });
});
