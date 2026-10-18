/**
 * Auth Session Resume Use Case
 *
 * Re-mints the session JWT for the SAME session row (POST /auth/session/resume).
 * The route's middleware has already proven a live session, so the 90-day owner
 * gate and conflict logic are deliberately NOT applied here — a resume must
 * never interrupt an active admin session. A missing or empty sessionId /
 * tenantId fails closed with SESSION_REVOKED. The legacy claim defaults live
 * HERE: `usr = dto.username ?? ''` and `role = dto.role ?? 'admin'`.
 *
 * Route obligation (wiring): source `username` and `role` from verified
 * middleware context (never request input) and keep the route's own
 * `!authSessionId → 401` guard.
 */
import type { SessionTokenService } from 'daftari-backend-shared/application/services/session-token-service';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { SessionResumeDto, SessionResumeResponse } from '../dtos/session-resume.dto';

/** Dashboard session JWT lifetime (seconds — JWT convention). */
const SESSION_TTL_S = 12 * 3600;

export class AuthSessionResumeUseCase {
  constructor(
    private readonly tokenService: SessionTokenService,
    private readonly userRepo: UserRepository,
    private readonly jwtSecret: string,
  ) {}

  async execute(dto: SessionResumeDto): Promise<SessionResumeResponse> {
    if (!dto.sessionId || !dto.tenantId) {
      return { ok: false, error: 'SESSION_REVOKED' };
    }
    const now = Date.now();
    const token = await this.tokenService.mint(
      {
        tid: dto.tenantId,
        usr: dto.username ?? '',
        role: dto.role ?? 'admin',
        jti: dto.sessionId,
        iat: Math.floor(now / 1000),
        exp: Math.floor(now / 1000) + SESSION_TTL_S,
      },
      this.jwtSecret,
    );
    const profile = await this.userRepo.findByTenantId(dto.tenantId);
    return { ok: true, data: { token, sessionId: dto.sessionId, profile } };
  }
}
