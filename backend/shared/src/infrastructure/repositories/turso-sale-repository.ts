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

  async insert(sale: Sale): Promise<void> {
    await this.db.insertSale({
      id: sale.id,
      tenantId: sale.tenantId,
      receiptJson: sale.receiptJson,
      totalPiastres: sale.totalPiastres,
      createdAt: sale.createdAt
    });
  }

  async listByTenantSince(tenantId: string, since: number): Promise<Sale[]> {
    const sales = await this.db.listSales(tenantId, since);
    return sales.map(sale => ({
      id: sale.id,
      tenantId: sale.tenant_id,
      receiptJson: sale.receipt_json,
      totalPiastres: sale.total_piastres,
      createdAt: sale.created_at
    }));
  }

  async getTenantStats(tenantId: string): Promise<{ saleCount: number; totalPiastres: number }> {
    return await this.db.getTenantStats(tenantId);
  }

  async getRecent(tenantId: string, limit: number): Promise<{ id: string; totalPiastres: number; createdAt: number }[]> {
    // This method needs to be implemented in TursoDb - for now we'll use listSales with since=0 and limit
    const sales = await this.db.listSales(tenantId, 0);
    const recentSales = sales.slice(0, limit).map(sale => ({
      id: sale.id,
      totalPiastres: sale.total_piastres,
      createdAt: sale.created_at
    }));
    return recentSales;
  }
}