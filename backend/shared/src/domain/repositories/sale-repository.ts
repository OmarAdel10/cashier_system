import { Sale } from '../entities/sale';

export interface SaleRepository {
  insert(sale: Sale): Promise<void>;
  listByTenantSince(tenantId: string, since: number): Promise<Sale[]>;
  getTenantStats(tenantId: string): Promise<{ saleCount: number; totalPiastres: number }>;
  getRecent(tenantId: string, limit: number): Promise<{ id: string; totalPiastres: number; createdAt: number }[]>;
}