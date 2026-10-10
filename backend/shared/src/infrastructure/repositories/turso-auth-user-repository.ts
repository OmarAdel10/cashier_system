import { inject, injectable } from 'tsyringe';
import { TursoDb } from '../../turso';
import { AuthUserRepository, NewAuthUser } from '../../domain/repositories/auth-user-repository';
import { AuthUser } from '../../domain/entities/auth-user';
import { AuthUserRecord } from '../../types';

@injectable()
export class TursoAuthUserRepository implements AuthUserRepository {
  constructor(
    @inject('TursoDb') private readonly db: TursoDb
  ) {}

  private toAuthUser(record: AuthUserRecord): AuthUser {
    if (record.role !== 'admin' && record.role !== 'cashier') {
      throw new Error('INVALID_AUTH_USER_ROLE');
    }
    return {
      tenantId: record.tenantId,
      username: record.username,
      passwordHash: record.passwordHash,
      role: record.role,
      displayName: record.displayName,
      mustChangePassword: record.mustChangePassword,
      isActive: record.isActive,
      failedAttempts: record.failedAttempts,
      lockedUntil: record.lockedUntil,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  async findByTenantAndUsername(tenantId: string, username: string): Promise<AuthUser | null> {
    const authUser = await this.db.getAuthUser(tenantId, username);
    if (!authUser) return null;
    return this.toAuthUser(authUser);
  }

  async listByTenant(tenantId: string): Promise<AuthUser[]> {
    const authUsers = await this.db.listAuthUsers(tenantId);
    return authUsers.map(user => this.toAuthUser(user));
  }

  async create(user: NewAuthUser): Promise<void> {
    await this.db.insertAuthUser(user);
  }

  async update(tenantId: string, username: string, patch: Partial<Omit<AuthUser, 'tenantId' | 'username' | 'createdAt'>>): Promise<void> {
    const dbPatch: Parameters<TursoDb['updateAuthUser']>[2] = {};
    if (patch.passwordHash !== undefined) {
      dbPatch.passwordHash = patch.passwordHash;
    }
    if (patch.displayName !== undefined) {
      dbPatch.displayName = patch.displayName;
    }
    if (patch.mustChangePassword !== undefined) {
      dbPatch.mustChangePassword = patch.mustChangePassword;
    }
    if (patch.isActive !== undefined) {
      dbPatch.isActive = patch.isActive;
    }
    if (patch.failedAttempts !== undefined) {
      dbPatch.failedAttempts = patch.failedAttempts;
    }
    if (patch.lockedUntil !== undefined) {
      dbPatch.lockedUntil = patch.lockedUntil;
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
