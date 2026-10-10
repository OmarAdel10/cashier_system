import { inject, injectable } from 'tsyringe';
import { TursoDb } from '../../turso';
import { SaleRepository } from '../../domain/repositories/sale-repository';
import { Sale } from '../../domain/entities/sale';
import { SaleRecord } from '../../types';

@injectable()
export class TursoSaleRepository implements SaleRepository {
  constructor(
    @inject('TursoDb') private readonly db: TursoDb
  ) {}

  private toSale(record: SaleRecord): Sale {
    return {
      id: record.id,
      tenantId: record.tenant_id,
      receiptJson: record.receipt_json,
      totalPiastres: record.total_piastres,
      createdAt: record.created_at,
    };
  }

  async insert(sale: Sale): Promise<void> {
    await this.db.insertSale({
      id: sale.id,
      tenant_id: sale.tenantId,
      receipt_json: sale.receiptJson,
      total_piastres: sale.totalPiastres,
      created_at: sale.createdAt,
    });
  }

  async listByTenantSince(tenantId: string, since: number): Promise<Sale[]> {
    const sales = await this.db.listSales(tenantId, since);
    return sales.map(sale => this.toSale(sale));
  }

  async getTenantStats(tenantId: string): Promise<{ saleCount: number; totalPiastres: number }> {
    return await this.db.getTenantStats(tenantId);
  }

  async getRecent(tenantId: string, limit: number): Promise<{ id: string; totalPiastres: number; createdAt: number }[]> {
    const sales = await this.db.getRecentSales(tenantId, limit);
    return sales.map(sale => ({
      id: sale.id,
      totalPiastres: sale.total_piastres,
      createdAt: sale.created_at,
    }));
  }

  async getUnsyncedSince(since: number): Promise<Sale[]> {
    // For now, we'll return empty array since we don't have a global unsynced sales table
    // In a real implementation, this would query a separate table or use a different mechanism
    return [];
  }
}
