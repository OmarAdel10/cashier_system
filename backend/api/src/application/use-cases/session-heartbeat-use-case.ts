/**
 * Session Heartbeat Use Case
 *
 * Updates the heartbeat timestamp for a live session, tenant-scoped so a
 * session cannot be touched outside its own tenant (404 IDOR is enforced at
 * the route by returning SESSION_NOT_FOUND when the row is absent).
 *
 * Wiring precondition (doc): identity fields (sessionId, tenantId) must be
 * sourced ONLY from verified middleware context at the wiring phase - never
 * from request body/query/header. Application layer trusts DTO input by
 * design; authz is a Phases 7-12 concern.
 */
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { SessionHeartbeatDto, SessionHeartbeatResponse } from '../dtos/session-heartbeat.dto';

export class SessionHeartbeatUseCase {
  constructor(private readonly sessionRepo: SessionRepository) {}

  async execute(dto: SessionHeartbeatDto): Promise<SessionHeartbeatResponse> {
    const now = Date.now();
    const recorded = await this.sessionRepo.heartbeat(
      dto.sessionId,
      dto.tenantId,
      now,
    );
    if (!recorded) {
      return { ok: false, error: 'SESSION_NOT_FOUND' };
    }
    return { ok: true };
  }
}
