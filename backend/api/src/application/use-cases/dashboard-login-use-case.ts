import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { AuthService } from 'daftari-backend-shared/domain/services/auth-service';
import type { RateLimiter } from 'daftari-backend-shared/domain/services/rate-limiter';
import type { SessionTokenService } from 'daftari-backend-shared/application/services/session-token-service';
import { DUMMY_HASH } from 'daftari-backend-shared/password_kdf';

/** Data Transfer Object for dashboard login request. */
export interface DashboardLoginDto {
  readonly tenantId: string;
  readonly username: string;
  readonly password: string;
  readonly ip: string;
}

/**
 * Login response type discriminated union matching current wire contract.
 */
export type DashboardLoginResponse =
  | {
      readonly ok: true;
      readonly data: {
        readonly token: string;
        readonly sessionId: string;
        readonly profile: {
          readonly tenantId: string;
          readonly email: string;
          readonly role: string;
          readonly tier?: string;
          readonly displayName?: string;
          readonly createdAt: number;
          readonly lastLoginAt: number;
          readonly lastOwnerLoginAt: number;
        };
      };
    }
  | {
      readonly ok: false;
      readonly error:
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
      readonly retryAfterMs?: number;
      readonly lockedUntil?: number;
      readonly conflictSessionId?: string;
    };

/** Dashboard session JWT lifetime (seconds). */
const SESSION_TTL_S = 12 * 3600;

/** Owner re-auth window: 90 days. */
const OWNER_REAUTH_MS = 90 * 24 * 3600 * 1000;

/** Session considered fresh for conflict detection: 5 minutes. */
const HEARTBEAT_FRESH_MS = 5 * 60 * 1000;

/**
 * Use case for dashboard (admin) authentication.
 *
 * Preserves exact current behavior including:
 * - Per-IP and per-account login throttling before KDF
 * - Constant-time dummy KDF for unknown users
 * - Exponential lockout handling (3rd failure = 2^3 * 15s, capped at 15min)
 * - Dashboard admin-only (cashier accounts rejected)
 * - Unconditional 90-day owner re-auth gate
 * - Active session conflict detection (stale >5min ignored)
 * - Web session hygiene (end prior web sessions)
 * - Atomic single-web-session admission
 * - Successful attempt marking
 */
export class DashboardLoginUseCase {
  constructor(
    private readonly authUserRepo: AuthUserRepository,
    private readonly sessionRepo: SessionRepository,
    private readonly licenseRepo: LicenseRepository,
    private readonly userRepo: UserRepository,
    private readonly authService: AuthService,
    private readonly rateLimiter: RateLimiter,
    private readonly tokenService: SessionTokenService,
    private readonly jwtSecret: string,
    private readonly passwordVerifier: (storedHash: string, password: string) => Promise<boolean>,
  ) {}

  async execute(dto: DashboardLoginDto): Promise<DashboardLoginResponse> {
    const now = Date.now();

    // Input validation
    if (
      !dto.tenantId.trim() ||
      !dto.username.trim() ||
      !dto.password.trim() ||
      !dto.ip.trim()
    ) {
      return { ok: false, error: 'MISSING_FIELDS', retryAfterMs: 0 };
    }

    // T17: throttle BEFORE the KDF and before touching auth_users
    const limit = await this.rateLimiter.checkLimit(
      dto.tenantId,
      dto.username,
      dto.ip,
      now,
    );
    if (!limit.allowed) {
      return { ok: false, error: 'RATE_LIMITED', retryAfterMs: limit.retryAfterMs };
    }
    await this.rateLimiter.recordAttempt(dto.tenantId, dto.username, dto.ip, false, now);

    // Reserve one concurrent verification slot before the expensive KDF
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

    // T16: KDF always runs, including for unknown usernames
    const derived = await this.passwordVerifier(
      authUser?.passwordHash ?? DUMMY_HASH,
      dto.password,
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

    // T16: elapsed lock window restarts the counter
    if (authUser?.lockedUntil != null && authUser.lockedUntil <= now) {
      await this.authUserRepo.resetFailures(dto.tenantId, dto.username);
    }

    const passwordOk = authUser != null && authUser.isActive === 1 && derived;
    if (!passwordOk) {
      if (authUser) {
        await recordFailure();
      }
      return { ok: false, error: 'BAD_CREDENTIALS', retryAfterMs: 0 };
    }

    // Dashboard logins are admin-role only
    if (authUser.role !== 'admin') {
      await release();
      return { ok: false, error: 'DASHBOARD_ADMIN_ONLY', retryAfterMs: 0 };
    }

    // 90-day owner re-auth gate
    const owner = await this.userRepo.findByTenantId(dto.tenantId);
    const ownerFresh =
      owner?.lastOwnerLoginAt != null &&
      Date.now() - owner.lastOwnerLoginAt <= OWNER_REAUTH_MS;
    if (!ownerFresh) {
      await release();
      return { ok: false, error: 'OWNER_REAUTH_REQUIRED', retryAfterMs: 0 };
    }

    // Per-username single-session conflict core
    const active = await this.sessionRepo.getActiveForUsername(
      dto.tenantId,
      dto.username,
      now - HEARTBEAT_FRESH_MS,
    );
    if (active.length > 0) {
      await release();
      return {
        ok: false,
        error: 'SESSION_CONFLICT',
        conflictSessionId: active[0]?.id,
      };
    }

    await this.authUserRepo.resetFailures(dto.tenantId, dto.username);
    // Web-session hygiene: end prior unended web rows
    await this.sessionRepo.endWebSessions(dto.tenantId, dto.username, now);

    const sessionId = `sess_${crypto.randomUUID()}`;
    // Atomic single-web-session admission
    const admitted = await this.sessionRepo.insert({
      id: sessionId,
      tenantId: dto.tenantId,
      deviceHwid: 'web',
      username: dto.username,
      startedAt: now,
      heartbeatAt: now,
      source: 'web',
    });
    if (!admitted) {
      await release();
      return { ok: false, error: 'SESSION_CONFLICT', retryAfterMs: 0 };
    }

    // Mark this successful attempt
    await this.rateLimiter.recordAttempt(dto.tenantId, dto.username, dto.ip, true, now);
    await release();

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
          tenantId: owner!.tenantId,
          email: owner!.email,
          role: owner!.role,
          tier: owner!.tier,
          displayName: owner!.displayName,
          createdAt: owner!.createdAt,
          lastLoginAt: now,
          lastOwnerLoginAt: now,
        },
      },
    };
  }
}
