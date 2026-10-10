import { inject, injectable } from 'tsyringe';
import { SessionRepository } from '../../domain/repositories/session-repository';
import { AuthUserRepository } from '../../domain/repositories/auth-user-repository';
import { DeviceRepository } from '../../domain/repositories/device-repository';
import { LicenseRepository } from '../../domain/repositories/license-repository';
import { UserRepository } from '../../domain/repositories/user-repository';

/**
 * Data Transfer Object for session start request.
 */
export interface SessionStartDto {
  /** Tenant identifier */
  tenantId: string;
  /** Hardware ID of the device starting the session */
  deviceHwid: string;
  /** Username for auth users, device identifier for POS */
  username: string;
  /** Session type: 'pos' (device) or 'web' (dashboard) */
  source: 'pos' | 'web';
}

/**
 * Session start response type discriminated union.
 */
export type SessionStartResponse =
  | {
      ok: true;
      data: {
        /** Created session identifier */
        sessionId: string;
      };
      error?: never;
    }
  | {
      ok: false;
      /** Error code: MISSING_FIELDS, INVALID_SOURCE, USER_NOT_FOUND, ACCOUNT_DISABLED, NO_LICENSE, LICENSE_EXPIRED, SESSION_CREATION_FAILED */
      error: string;
      /** Milliseconds until retry allowed */
      retryAfterMs?: number;
    };

/**
 * Use case for starting a new session (POS or web).
 *
 * Handles session creation for both POS devices and web dashboard logins.
 * For web sessions, validates auth user exists and is active.
 * For POS sessions, validates tenant has a valid license.
 *
 * @example
 * ```typescript
 * const sessionStartUseCase: SessionStartUseCase = container.resolve('SessionStartUseCase');
 *
 * // POS device session
 * const posResult = await sessionStartUseCase.execute({
 *   tenantId: 'tenant-123',
 *   deviceHwid: 'device-abc',
 *   username: 'device-abc',
 *   source: 'pos'
 * });
 *
 * // Web dashboard session
 * const webResult = await sessionStartUseCase.execute({
 *   tenantId: 'tenant-123',
 *   deviceHwid: 'web_1234567890',
 *   username: 'cashier1',
 *   source: 'web'
 * });
 * ```
 */
@injectable()
export class SessionStartUseCase {
  /**
   * Creates a SessionStartUseCase with injected dependencies.
   *
   * @param sessionRepo - Repository for session management
   * @param authUserRepo - Repository for auth user validation (web sessions)
   * @param licenseRepo - Repository for license validation (POS sessions)
   * @param deviceRepo - Repository for POS device registration
   * @param userRepo - Repository for tenant profile and tier lookup
   */
  constructor(
    @inject('SessionRepository') private readonly sessionRepo: SessionRepository,
    @inject('AuthUserRepository') private readonly authUserRepo: AuthUserRepository,
    @inject('LicenseRepository') private readonly licenseRepo: LicenseRepository,
    @inject('DeviceRepository') private readonly deviceRepo: DeviceRepository,
    @inject('UserRepository') private readonly userRepo: UserRepository
  ) {}

  /**
   * Executes the session start use case.
   *
   * @param dto - Session start parameters
   * @returns SessionStartResponse with sessionId on success, error on failure
   */
  async execute(dto: SessionStartDto): Promise<SessionStartResponse> {
    // Input validation
    if (
      !dto.tenantId?.trim() ||
      !dto.deviceHwid?.trim() ||
      !dto.username?.trim() ||
      !dto.source
    ) {
      return {
        ok: false,
        error: 'MISSING_FIELDS',
        retryAfterMs: 0
      };
    }

    // Validate source
    if (dto.source !== 'pos' && dto.source !== 'web') {
      return {
        ok: false,
        error: 'INVALID_SOURCE',
        retryAfterMs: 0
      };
    }

    const now = Date.now();

    if (dto.source === 'web') {
      const authUser = await this.authUserRepo.findByTenantAndUsername(
        dto.tenantId,
        dto.username,
      );
      if (!authUser) {
        return { ok: false, error: 'USER_NOT_FOUND', retryAfterMs: 0 };
      }
      if (!authUser.isActive) {
        return { ok: false, error: 'ACCOUNT_DISABLED', retryAfterMs: 0 };
      }

      // End the previous live dashboard session before inserting the replacement.
      // The partial unique web-session index still guards the concurrent case.
      await this.sessionRepo.endWebSessions(dto.tenantId, dto.username, now);

      const sessionId = `sess_${crypto.randomUUID()}`;
      const inserted = await this.sessionRepo.insert({
        id: sessionId,
        tenantId: dto.tenantId,
        deviceHwid: dto.deviceHwid,
        username: dto.username,
        startedAt: now,
        heartbeatAt: now,
        source: 'web',
      });
      if (!inserted) {
        return { ok: false, error: 'SESSION_CREATION_FAILED', retryAfterMs: 0 };
      }

      return { ok: true, data: { sessionId } };
    }

    // POS devices must have a valid tenant license before admission.
    const latestLicense = await this.licenseRepo.findLatestByTenant(dto.tenantId);
    if (!latestLicense) {
      return { ok: false, error: 'NO_LICENSE', retryAfterMs: 0 };
    }
    if (await this.licenseRepo.isExpired(latestLicense.graceEnd, now)) {
      return { ok: false, error: 'LICENSE_EXPIRED', retryAfterMs: 0 };
    }

    // The tenant profile determines the tier, and the tier determines the
    // number of live POS sessions that may be admitted concurrently.
    const tenantProfile = await this.userRepo.findByTenantId(dto.tenantId);
    const tier = tenantProfile?.tier ?? 'starter';
    const limit = this.licenseRepo.getDeviceLimit(tier);

    await this.deviceRepo.upsert({
      tenantId: dto.tenantId,
      deviceHwid: dto.deviceHwid,
      firstSeenAt: now,
      lastSeenAt: now,
    });

    // A reconnect must replace its prior row atomically with the new live row.
    await this.sessionRepo.endForDevice(dto.tenantId, dto.deviceHwid, now);

    const sessionId = `sess_${crypto.randomUUID()}`;
    const admitted = await this.sessionRepo.admitPosSession(
      {
        id: sessionId,
        tenantId: dto.tenantId,
        deviceHwid: dto.deviceHwid,
        username: dto.username,
        startedAt: now,
        heartbeatAt: now,
        source: 'pos',
      },
      limit,
    );
    if (!admitted) {
      return { ok: false, error: 'SESSION_CREATION_FAILED', retryAfterMs: 0 };
    }

    return { ok: true, data: { sessionId } };
  }
}
