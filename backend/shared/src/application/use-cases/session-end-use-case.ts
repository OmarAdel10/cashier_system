import { inject, injectable } from 'tsyringe';
import { SessionRepository } from '../../domain/repositories/session-repository';

/**
 * Data Transfer Object for session end request.
 */
export interface SessionEndDto {
  /** Tenant identifier */
  tenantId: string;
  /** Session identifier to end */
  sessionId: string;
}

/**
 * Session end response type discriminated union.
 */
export type SessionEndResponse =
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
      /** Error code: MISSING_FIELDS, SESSION_NOT_FOUND */
      error: string;
      /** Milliseconds until retry allowed */
      retryAfterMs?: number;
    };

/**
 * Use case for explicitly ending a session.
 *
 * Used when a POS device or web session needs to be explicitly terminated
 * (e.g., device logout, admin session management).
 *
 * @example
 * ```typescript
 * const sessionEndUseCase: SessionEndUseCase = container.resolve('SessionEndUseCase');
 * const result = await sessionEndUseCase.execute({
 *   tenantId: 'tenant-123',
 *   sessionId: 'sess_1234567890_abc123'
 * });
 * ```
 */
@injectable()
export class SessionEndUseCase {
  /**
   * Creates a SessionEndUseCase with injected dependencies.
   *
   * @param sessionRepo - Repository for session management
   */
  constructor(
    @inject('SessionRepository') private readonly sessionRepo: SessionRepository
  ) {}

  /**
   * Executes the session end use case.
   *
   * @param dto - Session to end
   * @returns SessionEndResponse with success message or error
   */
  async execute(dto: SessionEndDto): Promise<SessionEndResponse> {
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
        message: 'Session ended successfully'
      }
    };
  }
}