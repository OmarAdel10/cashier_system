import { inject, injectable } from 'tsyringe';
import { AuthUserRepository } from '../../domain/repositories/auth-user-repository';
import { SessionRepository } from '../../domain/repositories/session-repository';
import { LicenseRepository } from '../../domain/repositories/license-repository';
import { UserRepository } from '../../domain/repositories/user-repository';
import { AuthService } from '../../domain/services/auth-service';
import { RateLimiter } from '../../domain/services/rate-limiter';
import { UserProfile } from '../../types';

/**
 * Data Transfer Object for login request.
 */
export interface LoginDto {
  /** Tenant identifier */
  tenantId: string;
  /** Username (admin or cashier) */
  username: string;
  /** Plaintext password */
  password: string;
}

/**
 * Login response type discriminated union.
 * On success: ok=true with token, sessionId, and user profile.
 * On failure: ok=false with error code and optional retry/lockout info.
 */
export type LoginResponse =
  | {
      ok: true;
      data: {
        /** JWT token for authenticated requests */
        token: string;
        /** Session identifier */
        sessionId: string;
        /** User profile (snake_case for API compatibility) */
        profile: UserProfile;
      };
      error?: never;
    }
  | {
      ok: false;
      /** Error code: MISSING_FIELDS, RATE_LIMITED, BAD_CREDENTIALS, ACCOUNT_DISABLED, NO_LICENSE, LICENSE_EXPIRED, SESSION_CREATION_FAILED, USER_PROFILE_NOT_FOUND */
      error: string;
      /** Milliseconds until retry allowed (for rate limiting) */
      retryAfterMs?: number;
      /** Timestamp when account lockout expires (if locked) */
      lockedUntil?: number;
      /** Conflicting session ID (future use) */
      conflictSessionId?: string;
    };

/**
 * Use case for user authentication (login).
 *
 * Orchestrates the complete login flow:
 * 1. Validates input (presentation layer concern)
 * 2. Checks rate limits (application layer)
 * 3. Finds auth user (application layer)
 * 4. Validates credentials via AuthService (domain layer)
 * 5. Checks session conflicts via AuthService (domain layer)
 * 6. Validates license via LicenseRepository (domain layer)
 * 7. Creates session via SessionRepository (infrastructure)
 * 8. Updates user profile via UserRepository (infrastructure)
 * 9. Returns JWT token and profile
 *
 * Error codes returned:
 * - MISSING_FIELDS: Required fields not provided
 * - RATE_LIMITED: Too many login attempts
 * - BAD_CREDENTIALS: Invalid username/password
 * - ACCOUNT_DISABLED: Account is inactive
 * - NO_LICENSE: No license found for tenant
 * - LICENSE_EXPIRED: License grace period has ended
 * - SESSION_CREATION_FAILED: Failed to create session record
 * - USER_PROFILE_NOT_FOUND: User profile missing after login
 *
 * @example
 * ```typescript
 * const loginUseCase: AuthLoginUseCase = container.resolve('AuthLoginUseCase');
 * const result = await loginUseCase.execute({
 *   tenantId: 'tenant-123',
 *   username: 'cashier1',
 *   password: 'password123'
 * });
 *
 * if (result.ok) {
 *   console.log('Login successful:', result.data.token);
 * } else {
 *   console.error('Login failed:', result.error, result.retryAfterMs);
 * }
 * ```
 */
@injectable()
export class AuthLoginUseCase {
  /**
   * Creates an AuthLoginUseCase with injected dependencies.
   *
   * @param authUserRepo - Repository for auth user data
   * @param sessionRepo - Repository for session management
   * @param licenseRepo - Repository for license validation
   * @param userRepo - Repository for user profiles
   * @param authService - Domain service for auth business logic
   * @param rateLimiter - Domain service for rate limiting
   */
  constructor(
    @inject('AuthUserRepository') private readonly authUserRepo: AuthUserRepository,
    @inject('SessionRepository') private readonly sessionRepo: SessionRepository,
    @inject('LicenseRepository') private readonly licenseRepo: LicenseRepository,
    @inject('UserRepository') private readonly userRepo: UserRepository,
    @inject('AuthService') private readonly authService: AuthService,
    @inject('RateLimiter') private readonly rateLimiter: RateLimiter
  ) {}

  /**
   * Executes the login use case.
   *
   * @param dto - Login credentials
   * @returns LoginResponse with token/profile on success, error details on failure
   */
  async execute(dto: LoginDto): Promise<LoginResponse> {
    // Input validation - presentation layer concern (shape and primitives)
    if (!dto.tenantId || !dto.username || !dto.password) {
      return {
        ok: false,
        error: 'MISSING_FIELDS',
        retryAfterMs: 0
      };
    }

    // Rate limiting check - application layer concern
    const rateLimitCheck = await this.rateLimiter.checkLimit(dto.tenantId, dto.username);
    if (!rateLimitCheck.allowed) {
      return {
        ok: false,
        error: 'RATE_LIMITED',
        retryAfterMs: rateLimitCheck.retryAfterMs
      };
    }

    // Find user by username - application layer concern
    const authUser = await this.authUserRepo.findByTenantAndUsername(dto.tenantId, dto.username);
    if (!authUser) {
      // Record failed attempt for non-existent user (to prevent username enumeration)
      await this.authUserRepo.recordFailure(dto.tenantId, dto.username);
      // Still apply rate limit
      await this.rateLimiter.recordAttempt(dto.tenantId, dto.username);
      return {
        ok: false,
        error: 'BAD_CREDENTIALS',
        retryAfterMs: 1000
      };
    }

    // Check if account is active - application layer concern
    if (!authUser.isActive) {
      await this.authUserRepo.recordFailure(dto.tenantId, dto.username);
      await this.rateLimiter.recordAttempt(dto.tenantId, dto.username);
      return {
        ok: false,
        error: 'ACCOUNT_DISABLED',
        retryAfterMs: 1000
      };
    }

    // Validate credentials - domain layer concern
    const isValidPassword = await this.authService.validateCredentials(
      dto.password,
      authUser.passwordHash
    );

    if (!isValidPassword) {
      // Record failed attempt
      await this.authUserRepo.recordFailure(dto.tenantId, dto.username);
      await this.rateLimiter.recordAttempt(dto.tenantId, dto.username);

      // Check if account should be locked
      const lockoutMs = this.authService.calculateLockout(authUser.failedAttempts + 1);
      let lockedUntil: number | undefined;
      if (lockoutMs) {
        lockedUntil = Date.now() + lockoutMs;
        await this.authUserRepo.update(dto.tenantId, dto.username, {
          isActive: 0,
          lockedUntil: lockedUntil
        });
      }

      return {
        ok: false,
        error: 'BAD_CREDENTIALS',
        retryAfterMs: 1000,
        lockedUntil
      };
    }

    // Check for session conflicts - domain layer concern
    const activeSessions = await this.sessionRepo.getActiveForUsername(
      dto.tenantId,
      dto.username,
      Date.now() - 5 * 60 * 1000 // SESSION_FRESH_MS
    );

    if (activeSessions.length >= 1) {
      // For now, we'll allow multiple sessions but track them
      // In a more strict implementation, we might return a conflict
      // For POS systems, we might want to limit concurrent sessions
    }

    // Check license validity - domain layer concern
    const latestLicense = await this.licenseRepo.findLatestByTenant(dto.tenantId);
    if (!latestLicense) {
      return {
        ok: false,
        error: 'NO_LICENSE',
        retryAfterMs: 0
      };
    }

    // Check if license is expired
    const isExpired = await this.licenseRepo.isExpired(latestLicense.graceEnd, Date.now());

    if (isExpired) {
      return {
        ok: false,
        error: 'LICENSE_EXPIRED',
        retryAfterMs: 0
      };
    }

    // Reset failed attempts on successful password validation
    await this.authUserRepo.resetFailures(dto.tenantId, dto.username);

    // End any existing web sessions for this username (security measure)
    await this.sessionRepo.endWebSessions(dto.tenantId, dto.username, Date.now());

    // Create new session
    const sessionId = `sess_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const sessionCreated = await this.sessionRepo.insert({
      id: sessionId,
      tenantId: dto.tenantId,
      deviceHwid: `web_${Date.now()}`, // Web sessions get a special device ID
      username: dto.username,
      startedAt: Date.now(),
      heartbeatAt: Date.now(),
      endedAt: 0, // 0 means not ended
      source: 'web'
    });

    if (!sessionCreated) {
      return {
        ok: false,
        error: 'SESSION_CREATION_FAILED',
        retryAfterMs: 0
      };
    }

    // Update user's last login time
    await this.userRepo.upsert({
      tenantId: dto.tenantId,
      email: '', // We don't have email in AuthUser, but User entity expects it
      role: authUser.role,
      displayName: authUser.displayName,
      createdAt: authUser.createdAt,
      lastLoginAt: Date.now(),
      lastOwnerLoginAt: authUser.role === 'admin' ? Date.now() : undefined
    });

    // Get user profile for response
    const userProfile = await this.userRepo.findByTenantId(dto.tenantId);
    if (!userProfile) {
      // This shouldn't happen, but handle gracefully
      return {
        ok: false,
        error: 'USER_PROFILE_NOT_FOUND',
        retryAfterMs: 0
      };
    }

    // Generate JWT token (this would normally be done by a JWT service)
    // For now, we'll return a simple token structure
    const token = `jwt_${btoa(JSON.stringify({
      tenantId: dto.tenantId,
      username: dto.username,
      role: authUser.role,
      sessionId,
      exp: Math.floor(Date.now() / 1000) + 24 * 60 * 60 // 24 hours
    }))}`;

    // Return successful response
    return {
      ok: true,
      data: {
        token,
        sessionId,
        profile: {
          tenant_id: userProfile.tenantId,
          email: userProfile.email,
          role: userProfile.role,
          tier: userProfile.tier,
          display_name: userProfile.displayName,
          created_at: userProfile.createdAt,
          last_login_at: userProfile.lastLoginAt,
          last_owner_login_at: userProfile.lastOwnerLoginAt
        }
      }
    };
  }
}