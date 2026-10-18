/**
 * Session End Use Case
 *
 * Ends the one session named by the caller for its own tenant. Idempotent by
 * design: the repository ends only rows with `ended_at IS NULL`, so ending an
 * already-ended session is a no-op at the store layer. A missing session
 * returns SESSION_NOT_FOUND. Bearer-token verification stays a route concern.
 *
 * Wiring precondition (doc): identity fields (sessionId, tenantId) must be
 * sourced ONLY from verified middleware context at the wiring phase - never
 * from request body/query/header. Application layer trusts DTO input by
 * design; authz is a Phases 7-12 concern.
 */
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { SessionEndDto, SessionEndResponse } from '../dtos/session-end.dto';

export class SessionEndUseCase {
  constructor(private readonly sessionRepo: SessionRepository) {}

  async execute(dto: SessionEndDto): Promise<SessionEndResponse> {
    const now = Date.now();
    const ended = await this.sessionRepo.end(dto.sessionId, dto.tenantId, now);
    if (!ended) {
      return { ok: false, error: 'SESSION_NOT_FOUND' };
    }
    return { ok: true };
  }
}
