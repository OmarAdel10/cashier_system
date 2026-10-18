/**
 * Sync Firebase User Use Case
 *
 * Returns the tenant profile after the middleware's lazy-sync (POST
 * /auth/sync-user). When the row is not visible yet (read-after-write race),
 * falls back to the just-created profile shape WITHOUT writing: the middleware
 * owns the write.
 *
 * Wiring pin: identity fields (tenantId/sessionId/username/role) must be
 * sourced ONLY from verified middleware context at the wiring phase - never
 * from request body/query/header values (base precedent: cross-tenant tests,
 * backend/api/test/api.test.ts:1115-1134).
 */
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { SyncUserDto, SyncUserResponse } from '../dtos/sync-user.dto';

export class SyncFirebaseUserUseCase {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly licenseRepo: LicenseRepository,
  ) {}

  async execute(dto: SyncUserDto): Promise<SyncUserResponse> {
    const existing = await this.userRepo.findByTenantId(dto.tenantId);
    // Read post-lookup so the fallback createdAt uses post-read time (legacy
    // read Date.now() after the lookup).
    const now = Date.now();
    const profile = existing ?? {
      tenantId: dto.tenantId,
      email: dto.email ?? '',
      role: 'admin',
      createdAt: now,
    };
    const license = await this.licenseRepo.findLatestByTenant(dto.tenantId);
    return { ok: true, data: { profile, license } };
  }
}
