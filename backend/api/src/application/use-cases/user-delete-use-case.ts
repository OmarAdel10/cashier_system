/**
 * User Delete Use Case
 *
 * Soft-deactivates a cloud auth user (is_active = 0). The row stays for
 * audit; login rejects is_active = 0. Owner-only.
 *
 * Error arms: MISSING_FIELDS, USER_NOT_FOUND.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */
import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { UserDeleteDto, UserDeleteResponse } from '../dtos/user-delete.dto';
import { validateTenantId, validateUsername } from '../validation';

export class UserDeleteUseCase {
  constructor(private readonly authUserRepo: AuthUserRepository) {}

  async execute(dto: UserDeleteDto): Promise<UserDeleteResponse> {
    const { tenantId, username } = dto;
    if (!validateTenantId(tenantId)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }
    if (!validateUsername(username)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }

    const existing = await this.authUserRepo.findByTenantAndUsername(
      tenantId,
      username,
    );
    if (!existing) {
      return { ok: false, error: 'USER_NOT_FOUND' };
    }

    // Soft-deactivate: the row stays for audit; login rejects is_active = 0.
    await this.authUserRepo.update(tenantId, username, { isActive: 0 });
    return { ok: true };
  }
}
