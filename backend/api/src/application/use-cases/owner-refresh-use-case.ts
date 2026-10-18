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
