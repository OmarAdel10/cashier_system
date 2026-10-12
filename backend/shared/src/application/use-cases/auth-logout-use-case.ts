import { inject, injectable } from 'tsyringe';
import { SessionRepository } from '../../domain/repositories/session-repository';
import type { AuthenticatedPrincipal } from '../dtos/principal';

/**
 * Data Transfer Object for logout request.
 */
export interface LogoutDto {
  /** Authenticated principal that owns the session */
  readonly principal: AuthenticatedPrincipal;
  /** Session identifier to end */
  readonly sessionId: string;
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
 *   principal: { tenantId: 'tenant-123', sessionId: 'sess_1234567890_abc123' },
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
    // Input validation
    const principal = dto.principal;
    if (!principal) {
      return {
        ok: false,
        error: 'MISSING_FIELDS',
        retryAfterMs: 0
      };
    }

    if (
      !principal.tenantId.trim() ||
      !dto.sessionId.trim()
    ) {
      return {
        ok: false,
        error: 'MISSING_FIELDS',
        retryAfterMs: 0
      };
    }

    if (principal.sessionId !== undefined && !principal.sessionId.trim()) {
      return {
        ok: false,
        error: 'MISSING_FIELDS',
        retryAfterMs: 0
      };
    }

    // A trusted boundary may bind its session ID. If supplied, it must name
    // the same session being ended; otherwise this is an ownership failure.
    if (principal.sessionId !== undefined && principal.sessionId !== dto.sessionId) {
      return {
        ok: false,
        error: 'SESSION_NOT_FOUND',
        retryAfterMs: 0
      };
    }

    // End the session
    const sessionEnded = await this.sessionRepo.end(
      dto.sessionId,
      principal.tenantId,
      Date.now(),
    );

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
