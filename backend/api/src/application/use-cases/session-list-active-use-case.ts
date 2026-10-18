/**
 * Session List Active Use Case
 *
 * Lists all active (non-ended) sessions for a tenant. Mirrors GET
 * /sessions/active: returns the session list, which may be empty, with no
 * error arm triggered by an empty result.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { Session } from 'daftari-backend-shared/domain/entities/session';
import type {
  SessionListActiveDto,
  SessionListActiveResponse,
  SessionListActiveSession,
} from '../dtos/session-list-active.dto';

export class SessionListActiveUseCase {
  constructor(private readonly sessionRepo: SessionRepository) {}

  async execute(dto: SessionListActiveDto): Promise<SessionListActiveResponse> {
    const sessions = await this.sessionRepo.getActive(dto.tenantId);
    return {
      ok: true,
      data: {
        sessions: sessions.map((s: Session): SessionListActiveSession => ({
          sessionId: s.id,
          username: s.username,
          source: s.source ?? 'pos',
          startedAt: s.startedAt,
          heartbeatAt: s.heartbeatAt,
        })),
      },
    };
  }
}
