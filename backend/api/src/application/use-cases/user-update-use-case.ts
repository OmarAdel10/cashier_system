/**
 * User Update Use Case
 *
 * Patches a cloud auth user (password, display name, or active status).
 * Owner-only: session admins cannot modify other users.
 *
 * Error arms: MISSING_FIELDS, USER_NOT_FOUND, OWNER_ONLY.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 *
 * The route hashes the password via hashTagged() (KDF is infrastructure) and
 * passes the resulting scheme-tagged hash as passwordHash.
 */
import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { UserUpdateDto, UserUpdateResponse } from '../dtos/user-update.dto';
import {
  validateTenantId,
  validateUsername,
  validatePassword,
  validateDisplayName,
  validateIsActive,
} from '../validation';

export class UserUpdateUseCase {
  constructor(private readonly authUserRepo: AuthUserRepository) {}

  async execute(dto: UserUpdateDto): Promise<UserUpdateResponse> {
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

    const patch: { passwordHash?: string; displayName?: string; isActive?: number } = {};

    if (dto.passwordHash !== undefined) {
      if (!validatePassword(dto.passwordHash)) {
        return { ok: false, error: 'MISSING_FIELDS' };
      }
      patch.passwordHash = dto.passwordHash;
    }

    if (dto.displayName !== undefined) {
      if (!validateDisplayName(dto.displayName)) {
        return { ok: false, error: 'MISSING_FIELDS' };
      }
      // null or empty/whitespace string → clear the display name (store as undefined in DB)
      if (dto.displayName !== null) {
        const trimmed = dto.displayName.trim();
        if (trimmed !== '') {
          patch.displayName = trimmed;
        }
      }
    }

    if (dto.isActive !== undefined) {
      if (!validateIsActive(dto.isActive)) {
        return { ok: false, error: 'MISSING_FIELDS' };
      }
      patch.isActive = dto.isActive;
    }

    if (Object.keys(patch).length === 0) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }

    await this.authUserRepo.update(tenantId, username, patch);
    return { ok: true };
  }
}
