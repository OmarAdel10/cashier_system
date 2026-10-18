/**
 * Sync Firebase User Use Case
 *
 * Returns the tenant profile after the middleware's lazy-sync (POST
 * /auth/sync-user). When the row is not visible yet (read-after-write race),
 * falls back to the just-created profile shape WITHOUT writing: the middleware
 * owns the write.
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
    const now = Date.now();
    const profile = (await this.userRepo.findByTenantId(dto.tenantId)) ?? {
      tenantId: dto.tenantId,
      email: dto.email ?? '',
      role: 'admin',
      createdAt: now,
    };
    const license = await this.licenseRepo.findLatestByTenant(dto.tenantId);
    return { ok: true, data: { profile, license } };
  }
}
