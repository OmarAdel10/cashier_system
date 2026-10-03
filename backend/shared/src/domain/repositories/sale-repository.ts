import { Sale } from '../entities/sale';

/**
 * Repository interface for synced sale records.
 *
 * Provides operations for recording sales and querying for analytics,
 * reporting, and incremental synchronization.
 *
 * @example
 * ```typescript
 * const saleRepo: SaleRepository = container.resolve('SaleRepository');
 * await saleRepo.insert(sale);
 * const recent = await saleRepo.getRecent('tenant-123', 10);
 * const stats = await saleRepo.getTenantStats('tenant-123');
 * ```
 */
export interface SaleRepository {
  /**
   * Inserts a new sale record.
   *
   * @param sale - Sale entity to persist
   * @returns Promise that resolves when operation completes
   */
  insert(sale: Sale): Promise<void>;

  /**
   * Lists sales for a tenant since a given timestamp.
   *
   * Used for incremental sync and reporting.
   *
   * @param tenantId - Tenant identifier
   * @param since - Unix timestamp (ms) to filter sales created after
   * @returns Array of Sale entities
   */
  listByTenantSince(tenantId: string, since: number): Promise<Sale[]>;

  /**
   * Gets aggregate statistics for a tenant.
   *
   * @param tenantId - Tenant identifier
   * @returns Object with sale count and total amount in piastres
   */
  getTenantStats(tenantId: string): Promise<{ saleCount: number; totalPiastres: number }>;

  /**
   * Gets recent sales for a tenant (for dashboard/feed).
   *
   * Returns minimal sale data optimized for list views.
   *
   * @param tenantId - Tenant identifier
   * @param limit - Maximum number of sales to return
   * @returns Array of sale summaries (id, total, createdAt)
   */
  getRecent(tenantId: string, limit: number): Promise<{ id: string; totalPiastres: number; createdAt: number }[]>;

  /**
   * Gets all sales across all tenants since a timestamp.
   *
   * Used for global sync operations (analytics worker).
   *
   * @param since - Unix timestamp (ms) to filter sales created after
   * @returns Array of Sale entities from all tenants
   */
  getUnsyncedSince(since: number): Promise<Sale[]>;
}