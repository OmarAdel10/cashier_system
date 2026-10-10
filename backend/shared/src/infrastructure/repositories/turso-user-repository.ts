import { inject, injectable } from 'tsyringe';
import { TursoDb } from '../../turso';
import { UserRepository } from '../../domain/repositories/user-repository';
import { User } from '../../domain/entities/user';
import { UserProfile } from '../../types';

@injectable()
export class TursoUserRepository implements UserRepository {
  constructor(
    @inject('TursoDb') private readonly db: TursoDb
  ) {}

  private toUser(profile: UserProfile): User {
    return {
      tenantId: profile.tenant_id,
      email: profile.email,
      role: profile.role,
      tier: profile.tier,
      displayName: profile.display_name,
      createdAt: profile.created_at,
      lastLoginAt: profile.last_login_at,
      lastOwnerLoginAt: profile.last_owner_login_at,
    };
  }

  async upsert(user: User): Promise<void> {
    await this.db.upsertUser({
      tenant_id: user.tenantId,
      email: user.email,
      role: user.role,
      display_name: user.displayName,
      created_at: user.createdAt,
    });
  }

  async findByTenantId(tenantId: string): Promise<User | null> {
    const profile = await this.db.getUser(tenantId);
    if (!profile) return null;
    return this.toUser(profile);
  }
}
