/**
 * Dashboard Logout Use Case
 *
 * Ends the one session named by the caller — the bearer token's `jti` for its
 * own tenant (POST /auth/logout). Idempotent by design: the repository ends
 * only rows with `ended_at IS NULL`, so ending an already-ended session is a
 * silent no-op. A missing or empty sessionId / tenantId skips the repository
 * call and still returns ok. Bearer-token verification stays a route concern.
 *
 * Registration-order pin (wiring): the legacy route registers logout BEFORE
 * the `/auth/*` liveness middleware deliberately — logout must succeed even
 * for an already-ended session, and a double logout returns ok.
 *
 * Wiring pin: identity fields (tenantId/sessionId/username/role) must be
 * sourced ONLY from verified middleware context at the wiring phase - never
 * from request body/query/header values (base precedent: cross-tenant tests,
 * backend/api/test/api.test.ts:1115-1134).
 */
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { LogoutDto, LogoutResponse } from '../dtos/logout.dto';

export class DashboardLogoutUseCase {
  constructor(private readonly sessionRepo: SessionRepository) {}

  async execute(dto: LogoutDto): Promise<LogoutResponse> {
    if (!dto.sessionId || !dto.tenantId) {
      return { ok: true };
    }
    const now = Date.now();
    await this.sessionRepo.endForTenant(dto.sessionId, dto.tenantId, now);
    return { ok: true };
  }
}
