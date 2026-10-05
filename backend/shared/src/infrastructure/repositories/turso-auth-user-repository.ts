import { inject, injectable } from 'tsyringe';
import { TursoDb } from '../../turso';
import { AuthUserRepository, NewAuthUser } from '../../domain/repositories/auth-user-repository';
import { AuthUser } from '../../domain/entities/auth-user';

@injectable()
export class TursoAuthUserRepository implements AuthUserRepository {
  constructor(
    @inject('TursoDb') private readonly db: TursoDb
  ) {}

  async findByTenantAndUsername(tenantId: string, username: string): Promise<AuthUser | null> {
    const authUser = await this.db.getAuthUser(tenantId, username);
    if (!authUser) return null;

    return {
      tenantId: authUser.tenantId,
      username: authUser.username,
      passwordHash: authUser.passwordHash,
      role: authUser.role,
      displayName: authUser.displayName,
      mustChangePassword: authUser.mustChangePassword,
      isActive: authUser.isActive,
      failedAttempts: authUser.failedAttempts,
      lockedUntil: authUser.lockedUntil,
      createdAt: authUser.createdAt,
      updatedAt: authUser.updatedAt
    };
  }

  async listByTenant(tenantId: string): Promise<AuthUser[]> {
    const authUsers = await this.db.listAuthUsers(tenantId);
    return authUsers.map(user => ({
      tenantId: user.tenantId,
      username: user.username,
      passwordHash: user.passwordHash,
      role: user.role,
      displayName: user.displayName,
      mustChangePassword: user.mustChangePassword,
      isActive: user.isActive,
      failedAttempts: user.failedAttempts,
      lockedUntil: user.lockedUntil,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
    }));
  }

  async create(user: NewAuthUser): Promise<void> {
    await this.db.insertAuthUser({
      tenant_id: user.tenantId,
      username: user.username,
      password_hash: user.passwordHash,
      role: user.role,
      display_name: user.displayName as string | undefined,
      must_change_password: user.mustChangePassword as number | undefined
    });
  }

  async update(tenantId: string, username: string, patch: Partial<Omit<AuthUser, 'tenantId' | 'username' | 'createdAt'>>): Promise<void> {
    // Map camelCase patch to snake_case for the database
    const dbPatch: any = {};
    if (patch.passwordHash !== undefined) {
      dbPatch.password_hash = patch.passwordHash;
    }
    if (patch.displayName !== undefined) {
      dbPatch.display_name = patch.displayName;
    }
    if (patch.mustChangePassword !== undefined) {
      dbPatch.must_change_password = patch.mustChangePassword;
    }
    if (patch.isActive !== undefined) {
      dbPatch.is_active = patch.isActive;
    }
    if (patch.failedAttempts !== undefined) {
      dbPatch.failed_attempts = patch.failedAttempts;
    }
    if (patch.lockedUntil !== undefined) {
      dbPatch.locked_until = patch.lockedUntil;
    }
    // updatedAt is handled by the database method
    await this.db.updateAuthUser(tenantId, username, dbPatch);
  }

  async recordFailure(tenantId: string, username: string): Promise<void> {
    await this.db.recordAuthFailure(tenantId, username);
  }

  async reserveLoginAttempt(tenantId: string, username: string): Promise<boolean> {
    return await this.db.reserveLoginAttempt(tenantId, username);
  }

  async releaseLoginAttempt(tenantId: string, username: string): Promise<void> {
    await this.db.releaseLoginAttempt(tenantId, username);
  }

  async convertReservationToFailure(tenantId: string, username: string): Promise<void> {
    await this.db.convertReservationToFailure(tenantId, username);
  }

  async resetFailures(tenantId: string, username: string): Promise<void> {
    await this.db.resetAuthFailures(tenantId, username);
  }
}