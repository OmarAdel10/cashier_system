import { inject, injectable } from 'tsyringe';
import { SessionRepository } from '../../domain/repositories/session-repository';

/**
 * Data Transfer Object for logout request.
 */
export interface LogoutDto {
  /** Tenant identifier */
  tenantId: string;
  /** Session identifier to end */
  sessionId: string;
}

/**
 * Logout response type discriminated union.
 */
export type LogoutResponse =
  | {
      ok: true;
      data: {
        /** Success message */
        message: string;
      };
      error?: never;
    }
  | {
      ok: false;
      /** Error code: MISSING_FIELDS, MISSING_SESSION_ID, SESSION_NOT_FOUND */
      error: string;
      /** Milliseconds until retry allowed */
      retryAfterMs?: number;
    };

/**
 * Use case for user logout.
 *
 * Ends a specific session by ID. Used when user explicitly logs out
 * from the dashboard or POS device.
 *
 * @example
 * ```typescript
 * const logoutUseCase: AuthLogoutUseCase = container.resolve('AuthLogoutUseCase');
 * const result = await logoutUseCase.execute({
 *   tenantId: 'tenant-123',
 *   sessionId: 'sess_1234567890_abc123'
 * });
 * ```
 */
@injectable()
export class AuthLogoutUseCase {
  /**
   * Creates an AuthLogoutUseCase with injected dependencies.
   *
   * @param sessionRepo - Repository for session management
   */
  constructor(
    @inject('SessionRepository') private readonly sessionRepo: SessionRepository
  ) {}

  /**
   * Executes the logout use case.
   *
   * @param dto - Session to end
   * @returns LogoutResponse with success message or error
   */
  async execute(dto: LogoutDto): Promise<LogoutResponse> {
    // Input validation
    if (!dto.tenantId || !dto.sessionId) {
      return {
        ok: false,
        error: 'MISSING_FIELDS',
        retryAfterMs: 0
      };
    }

    // End the session
    const sessionEnded = await this.sessionRepo.end(dto.sessionId, dto.tenantId, Date.now());

    if (!sessionEnded) {
      return {
        ok: false,
        error: 'SESSION_NOT_FOUND',
        retryAfterMs: 0
      };
    }

    return {
      ok: true,
      data: {
        message: 'Logged out successfully'
      }
    };
  }
}