import { User } from '../entities/user';

export interface UserRepository {
  upsert(user: User): Promise<void>;
  findByTenantId(tenantId: string): Promise<User | null>;
}