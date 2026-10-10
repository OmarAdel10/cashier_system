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
      tenantId: profile.tenantId,
      email: profile.email,
      role: profile.role,
      tier: profile.tier,
      displayName: profile.displayName,
      createdAt: profile.createdAt,
      lastLoginAt: profile.lastLoginAt,
      lastOwnerLoginAt: profile.lastOwnerLoginAt,
    };
  }

  async upsert(user: User): Promise<void> {
    await this.db.upsertUser(user);
  }

  async findByTenantId(tenantId: string): Promise<User | null> {
    const profile = await this.db.getUser(tenantId);
    if (!profile) return null;
    return this.toUser(profile);
  }
}
