/**
 * Auth Session Resume Use Case
 *
 * Re-mints the session JWT for the SAME session row (POST /auth/session/resume).
 * The route's middleware has already proven a live session, so the 90-day owner
 * gate and conflict logic are deliberately NOT applied here — a resume must
 * never interrupt an active admin session. The error arm SESSION_REVOKED exists
 * in the DTO but is unreachable here: the middleware handles a missing session
 * row.
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
    const now = Date.now();
    const token = await this.tokenService.mint(
      {
        tid: dto.tenantId,
        usr: dto.username,
        role: dto.role,
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
