/**
 * Owner Refresh Use Case
 *
 * Stamps the owner's Firebase re-auth timestamp (POST /auth/owner-refresh).
 * No dedicated owner-touch method exists on the shared repository, so the
 * find+upsert mirror preserves the legacy `UPDATE ... WHERE tenant_id = ?`
 * semantics: a missing row is a silent no-op that still returns ok.
 *
 * PRECONDITION (wiring): the route MUST keep this use case behind
 * `requireOwner()`. Behind plain `requireAuth`, a session admin could keep the
 * tenant-wide 90-day owner re-auth gate permanently fresh — a gate bypass.
 * Wiring test obligation: session-admin → 403 OWNER_ONLY.
 *
 * DEVIATION FROM LEGACY (recorded - DAFTARI-127, medium): the legacy route
 * updated only last_owner_login_at via an atomic single-column UPDATE. This
 * use case uses find + full-row upsert (the only shape available on
 * UserRepository today). Consequences: (1) concurrent lost-update on
 * role/created_at/email; (2) when this use case is wired to the route, the
 * existing SQL-shape pin test (backend/api/test/api.test.ts:1613-1621,
 * single-column last_owner_login_at = ?) WILL FAIL - that failure is the
 * intended tripwire.
 * HARD WIRING GATE: do NOT wire this use case until DAFTARI-127 lands (add
 * touchOwnerLogin to shared UserRepository) or the pin test is consciously
 * re-approved and the residual risk re-assessed.
 *
 * Wiring pin: identity fields (tenantId/sessionId/username/role) must be
 * sourced ONLY from verified middleware context at the wiring phase - never
 * from request body/query/header values (base precedent: cross-tenant tests,
 * backend/api/test/api.test.ts:1115-1134).
 */
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { OwnerRefreshDto, OwnerRefreshResponse } from '../dtos/owner-refresh.dto';

export class OwnerRefreshUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(dto: OwnerRefreshDto): Promise<OwnerRefreshResponse> {
    // upsert writes the full row, so spread the existing profile and stamp
    // only lastOwnerLoginAt (email/role/tier/displayName/createdAt preserved).
    const user = await this.userRepo.findByTenantId(dto.tenantId);
    // Read post-lookup, matching legacy ordering (time captured at write time).
    const now = Date.now();
    if (user) {
      await this.userRepo.upsert({ ...user, lastOwnerLoginAt: now });
    }
    return { ok: true };
  }
}
