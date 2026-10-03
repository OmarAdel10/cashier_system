import { inject, injectable } from 'tsyringe';
import { SessionRepository } from '../../domain/repositories/session-repository';
import { Session } from '../../domain/entities/session';
import { AuthUserRepository } from '../../domain/repositories/auth-user-repository';
import { LicenseRepository } from '../../domain/repositories/license-repository';

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
   */
  constructor(
    @inject('SessionRepository') private readonly sessionRepo: SessionRepository,
    @inject('AuthUserRepository') private readonly authUserRepo: AuthUserRepository,
    @inject('LicenseRepository') private readonly licenseRepo: LicenseRepository
  ) {}

  /**
   * Executes the session start use case.
   *
   * @param dto - Session start parameters
   * @returns SessionStartResponse with sessionId on success, error on failure
   */
  async execute(dto: SessionStartDto): Promise<SessionStartResponse> {
    // Input validation
    if (!dto.tenantId || !dto.deviceHwid || !dto.username || !dto.source) {
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

    // For web sessions, check if user exists and is active
    if (dto.source === 'web') {
      const authUser = await this.authUserRepo.findByTenantAndUsername(dto.tenantId, dto.username);
      if (!authUser) {
        return {
          ok: false,
          error: 'USER_NOT_FOUND',
          retryAfterMs: 0
        };
      }

      if (!authUser.isActive) {
        return {
          ok: false,
          error: 'ACCOUNT_DISABLED',
          retryAfterMs: 0
        };
      }
    }

    // For POS sessions, check license validity
    if (dto.source === 'pos') {
      const latestLicense = await this.licenseRepo.findLatestByTenant(dto.tenantId);
      if (!latestLicense) {
        return {
          ok: false,
          error: 'NO_LICENSE',
          retryAfterMs: 0
        };
      }

      const isExpired = await this.licenseRepo.isExpired(latestLicense.graceEnd, Date.now());
      if (isExpired) {
        return {
          ok: false,
          error: 'LICENSE_EXPIRED',
          retryAfterMs: 0
        };
      }
    }

    // Create session
    const sessionId = `sess_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const sessionCreated = await this.sessionRepo.insert({
      id: sessionId,
      tenantId: dto.tenantId,
      deviceHwid: dto.deviceHwid,
      username: dto.username,
      startedAt: Date.now(),
      heartbeatAt: Date.now(),
      endedAt: 0,
      source: dto.source
    });

    if (!sessionCreated) {
      return {
        ok: false,
        error: 'SESSION_CREATION_FAILED',
        retryAfterMs: 0
      };
    }

    return {
      ok: true,
      data: {
        sessionId
      }
    };
  }
}