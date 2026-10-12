import { User } from '../entities/user';

/**
 * Repository interface for tenant user profiles.
 *
 * Provides CRUD operations for User entities. Implementations handle
 * persistence to Turso database with appropriate field mapping.
 *
 * @example
 * ```typescript
 * const userRepo: UserRepository = container.resolve('UserRepository');
 * await userRepo.upsert(user);
 * const profile = await userRepo.findByTenantId('tenant-123');
 * ```
 */
export interface UserRepository {
  /**
   * Creates or updates a user profile.
   *
   * @param user - User entity to persist
   * @returns Promise that resolves when operation completes
   */
  upsert(user: User): Promise<void>;

  /**
   * Finds a user profile by tenant ID.
   *
   * @param tenantId - Tenant identifier
   * @returns User entity or null if not found
   */
  findByTenantId(tenantId: string): Promise<User | null>;
}