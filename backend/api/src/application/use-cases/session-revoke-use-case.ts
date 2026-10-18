/**
 * Session Revoke Use Case
 *
 * Ends a session for its own tenant. Owner may revoke any username; a
 * non-owner may only revoke their own session — that username/isOwner
 * authorization check is a route/middleware concern (Phases 7-12) and is
 * deliberately NOT enforced here. The OWNER_ONLY arm is retained in the
 * response contract for the wiring layer to surface.
 *
 * Wiring precondition (doc): identity fields (sessionId, tenantId) must be
 * sourced ONLY from verified middleware context at the wiring phase - never
 * from request body/query/header. Application layer trusts DTO input by
 * design; authz is a Phases 7-12 concern.
 */
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { SessionRevokeDto, SessionRevokeResponse } from '../dtos/session-revoke.dto';

export class SessionRevokeUseCase {
  constructor(private readonly sessionRepo: SessionRepository) {}

  async execute(dto: SessionRevokeDto): Promise<SessionRevokeResponse> {
    const now = Date.now();
    const ended = await this.sessionRepo.end(dto.sessionId, dto.tenantId, now);
    if (!ended) {
      return { ok: false, error: 'SESSION_NOT_FOUND' };
    }
    return { ok: true };
  }
}
