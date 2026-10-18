/**
 * Branding Config Use Case
 *
 * Returns branding configuration for a tenant: primary color and optional
 * logo. Loads the latest license and tenant user profile, then derives the
 * branding values. Returns NO_LICENSE when no license exists for the tenant.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type {
  BrandingConfigDto,
  BrandingConfigResponse,
} from '../dtos/branding-config.dto';

export class BrandingConfigUseCase {
  constructor(
    private readonly licenseRepo: LicenseRepository,
    private readonly userRepo: UserRepository,
  ) {}

  async execute(dto: BrandingConfigDto): Promise<BrandingConfigResponse> {
    const { tenantId } = dto;
    const isNonEmptyString = (v: unknown): v is string =>
      typeof v === 'string' && v.trim().length > 0;
    if (!isNonEmptyString(tenantId)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }

    const license = await this.licenseRepo.findLatestByTenant(tenantId);
    if (license === null) {
      return { ok: false, error: 'NO_LICENSE' };
    }

    const user = await this.userRepo.findByTenantId(tenantId);

    return {
      ok: true,
      data: {
        primaryColor: user?.tier === 'business' ? '#1D4ED8' : '#3B82F6',
        logo: user?.displayName,
      },
    };
  }
}
