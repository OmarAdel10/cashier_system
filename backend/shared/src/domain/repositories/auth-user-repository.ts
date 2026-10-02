import { AuthUser } from '../entities/auth-user';
import { NewAuthUser } from '../../types'; // Keep this for now, will move later

export interface AuthUserRepository {
  findByTenantAndUsername(tenantId: string, username: string): Promise<AuthUser | null>;
  listByTenant(tenantId: string): Promise<AuthUser[]>;
  create(user: NewAuthUser): Promise<void>;
  update(tenantId: string, username: string, patch: Partial<Omit<AuthUser, 'tenantId' | 'username' | 'createdAt'>>): Promise<void>;
  recordFailure(tenantId: string, username: string): Promise<void>;
  reserveLoginAttempt(tenantId: string, username: string): Promise<boolean>;
  releaseLoginAttempt(tenantId: string, username: string): Promise<void>;
  convertReservationToFailure(tenantId: string, username: string): Promise<void>;
  resetFailures(tenantId: string, username: string): Promise<void>;
}