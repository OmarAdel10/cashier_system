import { inject, injectable } from 'tsyringe';
import { AuthUserRepository } from '../../domain/repositories/auth-user-repository';
import { SessionRepository } from '../../domain/repositories/session-repository';
import { LicenseRepository } from '../../domain/repositories/license-repository';
import { UserRepository } from '../../domain/repositories/user-repository';
import { AuthService } from '../../domain/services/auth-service';
import { RateLimiter } from '../../domain/services/rate-limiter';
import { DUMMY_HASH } from '../../password_kdf';
import type { SessionTokenService } from '../services/session-token-service';
import { UserProfile } from '../../types';

/** Dashboard session lifetime, matching the API's 12-hour login policy. */
const SESSION_TTL_S = 12 * 3600;

/** Data Transfer Object for login request. */
export interface LoginDto {
  /** Tenant identifier */
  tenantId: string;
  /** Username (admin or cashier) */
  username: string;
  /** Plaintext password */
  password: string;
  /** Trusted client IP used for the rate limiter. */
  ip: string;
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
        token: string;
        sessionId: string;
        profile: UserProfile;
      };
      error?: never;
    }
  | {
      ok: false;
      error:
        | 'MISSING_FIELDS'
        | 'RATE_LIMITED'
        | 'BAD_CREDENTIALS'
        | 'ACCOUNT_DISABLED'
        | 'DASHBOARD_ADMIN_ONLY'
        | 'OWNER_REAUTH_REQUIRED'
        | 'SESSION_CONFLICT'
        | 'NO_LICENSE'
        | 'LICENSE_EXPIRED'
        | 'SESSION_CREATION_FAILED'
        | 'USER_PROFILE_NOT_FOUND';
      retryAfterMs?: number;
      lockedUntil?: number;
      conflictSessionId?: string;
    };

/**
 * Use case for dashboard authentication.
 *
 * The account is never disabled by failed logins. Failed attempts are counted
 * and expire; a successful login starts a fresh failure window. The returned
 * token is a real HS256 JWT bound to a live web-session row.
 */
@injectable()
export class AuthLoginUseCase {
  constructor(
    @inject('AuthUserRepository') private readonly authUserRepo: AuthUserRepository,
    @inject('SessionRepository') private readonly sessionRepo: SessionRepository,
    @inject('LicenseRepository') private readonly licenseRepo: LicenseRepository,
    @inject('UserRepository') private readonly userRepo: UserRepository,
    @inject('AuthService') private readonly authService: AuthService,
    @inject('RateLimiter') private readonly rateLimiter: RateLimiter,
    @inject('SessionTokenService') private readonly tokenService: SessionTokenService,
    @inject('AdminJwtSecret') private readonly jwtSecret: string,
  ) {}

  async execute(dto: LoginDto): Promise<LoginResponse> {
    const now = Date.now();
    if (!dto.tenantId || !dto.username || !dto.password || !dto.ip) {
      return { ok: false, error: 'MISSING_FIELDS', retryAfterMs: 0 };
    }

    const limit = await this.rateLimiter.checkLimit(
      dto.tenantId,
      dto.username,
      dto.ip,
      now,
    );
    if (!limit.allowed) {
      return { ok: false, error: 'RATE_LIMITED', retryAfterMs: limit.retryAfterMs };
    }

    // Reserve one concurrent verification slot before the expensive KDF.
    const reserved = await this.authUserRepo.reserveLoginAttempt(
      dto.tenantId,
      dto.username,
    );
    if (!reserved) {
      return { ok: false, error: 'RATE_LIMITED', retryAfterMs: 0 };
    }

    const release = async () =>
      this.authUserRepo.releaseLoginAttempt(dto.tenantId, dto.username);
    const recordFailure = async () => {
      await this.authUserRepo.convertReservationToFailure(dto.tenantId, dto.username);
      await this.rateLimiter.recordAttempt(dto.tenantId, dto.username, dto.ip, false, now);
    };

    const authUser = await this.authUserRepo.findByTenantAndUsername(
      dto.tenantId,
      dto.username,
    );

    // KDF always runs, including for unknown usernames, so response timing
    // cannot be used to enumerate accounts.
    const derived = await this.authService.validateCredentials(
      dto.password,
      authUser?.passwordHash ?? DUMMY_HASH,
    );

    if (authUser?.lockedUntil != null && authUser.lockedUntil > now) {
      await release();
      await this.rateLimiter.recordAttempt(dto.tenantId, dto.username, dto.ip, false, now);
      return {
        ok: false,
        error: 'RATE_LIMITED',
        retryAfterMs: Math.max(0, authUser.lockedUntil - now),
      };
    }

    if (authUser?.lockedUntil != null && authUser.lockedUntil <= now) {
      await this.authUserRepo.resetFailures(dto.tenantId, dto.username);
    }

    if (!authUser || !derived) {
      await recordFailure();
      return { ok: false, error: 'BAD_CREDENTIALS', retryAfterMs: 0 };
    }

    if (!authUser.isActive) {
      await release();
      return { ok: false, error: 'ACCOUNT_DISABLED', retryAfterMs: 0 };
    }

    if (authUser.role !== 'admin') {
      await release();
      return { ok: false, error: 'DASHBOARD_ADMIN_ONLY', retryAfterMs: 0 };
    }

    const existingProfile = await this.userRepo.findByTenantId(dto.tenantId);
    if (!existingProfile) {
      await release();
      return { ok: false, error: 'USER_PROFILE_NOT_FOUND', retryAfterMs: 0 };
    }
    if (this.authService.shouldRequireOwnerReauth(existingProfile.lastOwnerLoginAt)) {
      await release();
      return { ok: false, error: 'OWNER_REAUTH_REQUIRED', retryAfterMs: 0 };
    }

    const license = await this.licenseRepo.findLatestByTenant(dto.tenantId);
    if (!license) {
      await release();
      return { ok: false, error: 'NO_LICENSE', retryAfterMs: 0 };
    }
    if (await this.licenseRepo.isExpired(license.graceEnd, now)) {
      await release();
      return { ok: false, error: 'LICENSE_EXPIRED', retryAfterMs: 0 };
    }

    await release();
    await this.authUserRepo.resetFailures(dto.tenantId, dto.username);
    await this.rateLimiter.recordAttempt(dto.tenantId, dto.username, dto.ip, true, now);

    const activeSessions = await this.sessionRepo.getActiveForUsername(
      dto.tenantId,
      dto.username,
      now - 5 * 60 * 1000,
    );
    if (activeSessions.length > 0) {
      return {
        ok: false,
        error: 'SESSION_CONFLICT',
        conflictSessionId: activeSessions[0]?.id,
      };
    }

    await this.sessionRepo.endWebSessions(dto.tenantId, dto.username, now);

    const sessionId = `sess_${crypto.randomUUID()}`;
    const inserted = await this.sessionRepo.insert({
      id: sessionId,
      tenantId: dto.tenantId,
      deviceHwid: `web_${crypto.randomUUID()}`,
      username: dto.username,
      startedAt: now,
      heartbeatAt: now,
      source: 'web',
    });
    if (!inserted) {
      return { ok: false, error: 'SESSION_CREATION_FAILED', retryAfterMs: 0 };
    }

    await this.userRepo.upsert({
      tenantId: dto.tenantId,
      email: existingProfile.email,
      role: authUser.role,
      displayName: authUser.displayName,
      createdAt: existingProfile.createdAt,
      lastLoginAt: now,
      lastOwnerLoginAt: now,
    });

    const token = await this.tokenService.mint(
      {
        tid: dto.tenantId,
        usr: dto.username,
        role: authUser.role,
        jti: sessionId,
        iat: Math.floor(now / 1000),
        exp: Math.floor(now / 1000) + SESSION_TTL_S,
      },
      this.jwtSecret,
    );

    return {
      ok: true,
      data: {
        token,
        sessionId,
        profile: {
          tenant_id: existingProfile.tenantId,
          email: existingProfile.email,
          role: existingProfile.role,
          tier: existingProfile.tier,
          display_name: existingProfile.displayName,
          created_at: existingProfile.createdAt,
          last_login_at: now,
          last_owner_login_at: now,
        },
      },
    };
  }
}
