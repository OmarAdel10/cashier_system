/**
 * Get Auth Profile Use Case
 *
 * Returns the tenant profile and its latest license (GET /auth/me). Both are
 * nullable: a missing user row is a legitimate 200 with `profile: null` in the
 * legacy route, so the USER_NOT_FOUND error arm stays unreachable.
 */
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { MeDto, MeResponse } from '../dtos/me.dto';

export class GetAuthProfileUseCase {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly licenseRepo: LicenseRepository,
  ) {}

  async execute(dto: MeDto): Promise<MeResponse> {
    const profile = await this.userRepo.findByTenantId(dto.tenantId);
    const license = await this.licenseRepo.findLatestByTenant(dto.tenantId);
    return { ok: true, data: { profile, license } };
  }
}
