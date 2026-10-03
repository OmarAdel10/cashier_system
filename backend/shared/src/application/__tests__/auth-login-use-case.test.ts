import 'reflect-metadata';
import { AuthLoginUseCase } from '../use-cases/auth-login-use-case';
import { LoginDto, LoginResponse } from '../use-cases/auth-login-use-case';
import { AuthUserRepository } from '../../domain/repositories/auth-user-repository';
import { SessionRepository } from '../../domain/repositories/session-repository';
import { LicenseRepository } from '../../domain/repositories/license-repository';
import { UserRepository } from '../../domain/repositories/user-repository';
import { AuthService } from '../../domain/services/auth-service';
import { RateLimiter } from '../../domain/services/rate-limiter';
import { faker } from '@faker-js/faker';
import { describe, expect, it, vi, beforeEach, Mock } from 'vitest';

describe('AuthLoginUseCase', () => {
  let useCase: AuthLoginUseCase;
  let mockAuthUserRepo: Partial<AuthUserRepository>;
  let mockSessionRepo: Partial<SessionRepository>;
  let mockLicenseRepo: Partial<LicenseRepository>;
  let mockUserRepo: Partial<UserRepository>;
  let mockAuthService: Partial<AuthService>;
  let mockRateLimiter: Partial<RateLimiter>;

  const validDto: LoginDto = {
    tenantId: faker.string.uuid(),
    username: faker.internet.username(),
    password: faker.internet.password()
  };

  beforeEach(() => {
    mockAuthUserRepo = {
      findByTenantAndUsername: vi.fn(),
      recordFailure: vi.fn(),
      update: vi.fn(),
      resetFailures: vi.fn()
    };
    mockSessionRepo = {
      getActiveForUsername: vi.fn().mockResolvedValue([]),
      endWebSessions: vi.fn(),
      insert: vi.fn().mockResolvedValue(true)
    };
    mockLicenseRepo = {
      findLatestByTenant: vi.fn(),
      isExpired: vi.fn()
    };
    mockUserRepo = {
      upsert: vi.fn(),
      findByTenantId: vi.fn()
    };
    mockAuthService = {
      validateCredentials: vi.fn().mockResolvedValue(true),
      shouldRequireOwnerReauth: vi.fn().mockReturnValue(false),
      isSessionConflict: vi.fn().mockReturnValue(false),
      calculateLockout: vi.fn().mockReturnValue(null)
    };
    mockRateLimiter = {
      checkLimit: vi.fn().mockResolvedValue({ allowed: true, retryAfterMs: 0 }),
      recordAttempt: vi.fn(),
      resetAttempts: vi.fn()
    };

    useCase = new AuthLoginUseCase(
      mockAuthUserRepo as AuthUserRepository,
      mockSessionRepo as SessionRepository,
      mockLicenseRepo as LicenseRepository,
      mockUserRepo as UserRepository,
      mockAuthService as AuthService,
      mockRateLimiter as RateLimiter
    );
  });

  it('should return BAD_CREDENTIALS for invalid password', async () => {
    // Arrange
    (mockAuthUserRepo.findByTenantAndUsername as vi.Mock).mockResolvedValue(null);
    (mockAuthService.validateCredentials as vi.Mock).mockResolvedValue(false);

    // Act
    const result = await useCase.execute(validDto) as LoginResponse;

    // Assert
    expect(result.ok).toBe(false);
    expect(result.error).toBe('BAD_CREDENTIALS');
  });

  it('should return ACCOUNT_DISABLED for inactive user', async () => {
    // Arrange
    const authUser = {
      tenantId: validDto.tenantId,
      username: validDto.username,
      passwordHash: 'hash',
      role: 'cashier',
      displayName: undefined,
      mustChangePassword: 0,
      isActive: 0,
      failedAttempts: 0,
      lockedUntil: undefined,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
    (mockAuthUserRepo.findByTenantAndUsername as vi.Mock).mockResolvedValue(authUser);
    (mockAuthService.validateCredentials as vi.Mock).mockResolvedValue(true);

    // Act
    const result = await useCase.execute(validDto) as LoginResponse;

    // Assert
    expect(result.ok).toBe(false);
    expect(result.error).toBe('ACCOUNT_DISABLED');
  });

  it('should return NO_LICENSE when no license exists', async () => {
    // Arrange
    const authUser = {
      tenantId: validDto.tenantId,
      username: validDto.username,
      passwordHash: 'hash',
      role: 'cashier',
      displayName: undefined,
      mustChangePassword: 0,
      isActive: 1,
      failedAttempts: 0,
      lockedUntil: undefined,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
    (mockAuthUserRepo.findByTenantAndUsername as vi.Mock).mockResolvedValue(authUser);
    (mockAuthService.validateCredentials as vi.Mock).mockResolvedValue(true);
    (mockLicenseRepo.findLatestByTenant as vi.Mock).mockResolvedValue(null);

    // Act
    const result = await useCase.execute(validDto) as LoginResponse;

    // Assert
    expect(result.ok).toBe(false);
    expect(result.error).toBe('NO_LICENSE');
  });

  it('should return LICENSE_EXPIRED when license is expired', async () => {
    // Arrange
    const authUser = {
      tenantId: validDto.tenantId,
      username: validDto.username,
      passwordHash: 'hash',
      role: 'cashier',
      displayName: undefined,
      mustChangePassword: 0,
      isActive: 1,
      failedAttempts: 0,
      lockedUntil: undefined,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
    const license = {
      tenantId: validDto.tenantId,
      deviceHwid: 'device123',
      licenseKey: 'key123',
      subscriptionEnd: Date.now() + 30 * 24 * 60 * 60 * 1000, // 30 days from now
      billingCycle: 'monthly',
      graceEnd: 0, // Lifetime license
      status: 'active',
      createdAt: Date.now() - 60 * 24 * 60 * 60 * 1000 // 60 days ago
    };
    (mockAuthUserRepo.findByTenantAndUsername as vi.Mock).mockResolvedValue(authUser);
    (mockAuthService.validateCredentials as vi.Mock).mockResolvedValue(true);
    (mockLicenseRepo.findLatestByTenant as vi.Mock).mockResolvedValue(license);
    (mockLicenseRepo.isExpired as vi.Mock).mockReturnValue(true);

    // Act
    const result = await useCase.execute(validDto) as LoginResponse;

    // Assert
    expect(result.ok).toBe(false);
    expect(result.error).toBe('LICENSE_EXPIRED');
  });

  it('should return successful login response when all validations pass', async () => {
    // Arrange
    const authUser = {
      tenantId: validDto.tenantId,
      username: validDto.username,
      passwordHash: 'hash',
      role: 'cashier',
      displayName: 'Test User',
      mustChangePassword: 0,
      isActive: 1,
      failedAttempts: 0,
      lockedUntil: undefined,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
    const license = {
      tenantId: validDto.tenantId,
      deviceHwid: 'device123',
      licenseKey: 'key123',
      subscriptionEnd: Date.now() + 30 * 24 * 60 * 60 * 1000, // 30 days from now
      billingCycle: 'monthly',
      graceEnd: 0, // Lifetime license
      status: 'active',
      createdAt: Date.now() - 60 * 24 * 60 * 60 * 1000 // 60 days ago
    };
    const expectedProfile = {
      tenant_id: validDto.tenantId,
      email: 'test@example.com',
      role: 'cashier',
      tier: 'pro',
      display_name: 'Test User',
      created_at: Date.now(),
      last_login_at: undefined,
      last_owner_login_at: undefined
    };
    const userProfile = {
      tenantId: validDto.tenantId,
      email: 'test@example.com',
      role: 'cashier',
      tier: 'pro',
      displayName: 'Test User',
      createdAt: Date.now(),
      lastLoginAt: undefined,
      lastOwnerLoginAt: undefined
    };
    (mockAuthUserRepo.findByTenantAndUsername as vi.Mock).mockResolvedValue(authUser);
    (mockAuthService.validateCredentials as vi.Mock).mockResolvedValue(true);
    (mockLicenseRepo.findLatestByTenant as vi.Mock).mockResolvedValue(license);
    (mockLicenseRepo.isExpired as vi.Mock).mockReturnValue(false);
    (mockUserRepo.upsert as vi.Mock).mockResolvedValue(undefined);
    (mockUserRepo.findByTenantId as vi.Mock).mockResolvedValue(userProfile);

    // Act
    const result = await useCase.execute(validDto) as LoginResponse;

    // Assert
    expect(result.ok).toBe(true);
    expect(result.data).toBeDefined();
    expect(result.data.token).toBeDefined();
    expect(result.data.sessionId).toBeDefined();
    expect(result.data.profile).toEqual(expectedProfile);
  });
});