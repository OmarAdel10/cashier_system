/**
 * User List Use Case
 *
 * Lists cloud auth users (admins/cashiers) for a tenant. Mirrors the user
 * management endpoint: returns the user list, which may be empty, with no
 * error arm triggered by an empty result. Results are capped at 50
 * (session-list-active precedent).
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */
import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { AuthUser } from 'daftari-backend-shared/domain/entities/auth-user';
import type {
  UserListDto,
  UserListResponse,
  UserListItem,
} from '../dtos/user-list.dto';
import { validateTenantId } from '../validation';

/** Maximum number of users returned per list request. */
const USER_LIST_LIMIT = 50;

export class UserListUseCase {
  constructor(private readonly authUserRepo: AuthUserRepository) {}

  async execute(dto: UserListDto): Promise<UserListResponse> {
    const { tenantId } = dto;
    if (!validateTenantId(tenantId)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }

    const users = await this.authUserRepo.listByTenant(tenantId);
    return {
      ok: true,
      data: {
        users: users
          .slice(0, USER_LIST_LIMIT)
          .map((u: AuthUser): UserListItem => ({
            id: u.username,
            username: u.username,
            role: u.role,
            displayName: u.displayName,
            isActive: u.isActive,
          })),
      },
    };
  }
}
