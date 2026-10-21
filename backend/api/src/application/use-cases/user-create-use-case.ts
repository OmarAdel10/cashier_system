/**
 * User Create Use Case
 *
 * Creates a new cloud auth user (admin or cashier) for a tenant.
 * Enforces tier requirements and owner-only admin management per spec §2.4.
 *
 * Error arms: MISSING_FIELDS, TIER_REQUIRED, ADMIN_MANAGEMENT_OWNER_ONLY,
 * USERNAME_TAKEN.
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
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { UserCreateDto, UserCreateResponse } from '../dtos/user-create.dto';
import {
  validateTenantId,
  validateUsername,
  validateRole,
  validateDisplayName,
} from '../validation';

export class UserCreateUseCase {
  constructor(
    private readonly authUserRepo: AuthUserRepository,
    private readonly userRepo: UserRepository,
  ) {}

  async execute(dto: UserCreateDto): Promise<UserCreateResponse> {
    const { tenantId, username, role, displayName, isOwner } = dto;
    if (!validateTenantId(tenantId)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }
    if (!validateUsername(username)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }
    if (!validateRole(role)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }
    if (!validateDisplayName(displayName)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }

    // Tier check: starter tier cannot manage users.
    const user = await this.userRepo.findByTenantId(tenantId);
    const tier = user?.tier ?? 'starter';
    if (tier === 'starter') {
      return { ok: false, error: 'TIER_REQUIRED' };
    }

    // Owner-only admin management: session admins may only create cashiers.
    if (role === 'admin' && !isOwner) {
      return { ok: false, error: 'ADMIN_MANAGEMENT_OWNER_ONLY' };
    }

    // Duplicate username check.
    const existing = await this.authUserRepo.findByTenantAndUsername(
      tenantId,
      username,
    );
    if (existing) {
      return { ok: false, error: 'USERNAME_TAKEN' };
    }

    const trimmedDisplayName = displayName ? displayName.trim() || undefined : undefined;

    await this.authUserRepo.create({
      tenantId,
      username,
      passwordHash: dto.passwordHash,
      role,
      displayName: trimmedDisplayName,
    });

    return {
      ok: true,
      data: {
        username,
        role,
        display_name: trimmedDisplayName,
      },
    };
  }
}
