/**
 * Admin Settings Use Case
 *
 * Returns admin settings for a tenant: pricing tier, device limit, and
 * license status. Loads the tenant user profile and latest license, then
 * maps them to the settings shape. No error arm is triggered by a missing
 * user profile beyond USER_NOT_FOUND, or by a missing license beyond
 * NO_LICENSE.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type {
  AdminSettingsDto,
  AdminSettingsResponse,
} from '../dtos/admin-settings.dto';
import { validateTenantId } from '../validation';

export class AdminSettingsUseCase {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly licenseRepo: LicenseRepository,
  ) {}

  async execute(dto: AdminSettingsDto): Promise<AdminSettingsResponse> {
    const { tenantId } = dto;
    if (!validateTenantId(tenantId)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }

    const user = await this.userRepo.findByTenantId(tenantId);
    if (user === null) {
      return { ok: false, error: 'USER_NOT_FOUND' };
    }

    const license = await this.licenseRepo.findLatestByTenant(tenantId);
    if (license === null) {
      return { ok: false, error: 'NO_LICENSE' };
    }

    const expired = await this.licenseRepo.isExpired(
      license.graceEnd,
      Date.now(),
    );
    const deviceLimit = this.licenseRepo.getDeviceLimit(
      user.tier ?? 'starter',
    );

    return {
      ok: true,
      data: {
        tier: user.tier ?? 'starter',
        deviceLimit,
        licenseStatus: expired ? 'expired' : 'active',
      },
    };
  }
}
