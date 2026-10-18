/**
 * Dashboard Logout Use Case
 *
 * Ends the one session named by the caller — the bearer token's `jti` for its
 * own tenant (POST /auth/logout). Idempotent by design: the repository ends
 * only rows with `ended_at IS NULL`, so ending an already-ended session is a
 * silent no-op. Bearer-token verification stays a route concern.
 */
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { LogoutDto, LogoutResponse } from '../dtos/logout.dto';

export class DashboardLogoutUseCase {
  constructor(private readonly sessionRepo: SessionRepository) {}

  async execute(dto: LogoutDto): Promise<LogoutResponse> {
    const now = Date.now();
    await this.sessionRepo.endForTenant(dto.sessionId, dto.tenantId, now);
    return { ok: true };
  }
}
