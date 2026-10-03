import { inject, injectable } from 'tsyringe';
import { TursoDb } from '../../turso';
import { AuthUserRepository } from '../../domain/repositories/auth-user-repository';
import { AuthUser } from '../../domain/entities/auth-user';
import { AuthUserRecord, NewAuthUser } from '../../types';

@injectable()
export class TursoAuthUserRepository implements AuthUserRepository {
  constructor(
    @inject('TursoDb') private readonly db: TursoDb
  ) {}

  async findByTenantAndUsername(tenantId: string, username: string): Promise<AuthUser | null> {
    const authUser = await this.db.getAuthUser(tenantId, username);
    if (!authUser) return null;

    return {
      tenantId: authUser.tenant_id,
      username: authUser.username,
      passwordHash: authUser.password_hash,
      role: authUser.role,
      displayName: authUser.display_name,
      mustChangePassword: authUser.must_change_password,
      isActive: authUser.is_active,
      failedAttempts: authUser.failed_attempts,
      lockedUntil: authUser.locked_until,
      createdAt: authUser.created_at,
      updatedAt: authUser.updated_at
    };
  }

  async listByTenant(tenantId: string): Promise<AuthUser[]> {
    const authUsers = await this.db.listAuthUsers(tenantId);
    return authUsers.map(user => ({
      tenantId: user.tenant_id,
      username: user.username,
      passwordHash: user.password_hash,
      role: user.role,
      displayName: user.display_name,
      mustChangePassword: user.must_change_password,
      isActive: user.is_active,
      failedAttempts: user.failed_attempts,
      lockedUntil: user.locked_until,
      createdAt: user.created_at,
      updatedAt: user.updated_at
    }));
  }

  async create(user: NewAuthUser): Promise<void> {
    await this.db.insertAuthUser(user);
  }

  async update(tenantId: string, username: string, patch: Partial<Omit<AuthUser, 'tenantId' | 'username' | 'createdAt'>>): Promise<void> {
    await this.db.updateAuthUser(tenantId, username, patch as any);
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