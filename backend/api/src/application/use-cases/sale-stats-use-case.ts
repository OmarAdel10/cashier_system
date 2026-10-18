/**
 * Sale Stats Use Case
 *
 * Returns aggregate sales statistics for a tenant. Mirrors the sale stats
 * endpoint: total sale count and total revenue in piastres. No error arm is
 * triggered by an empty result.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */
import type { SaleRepository } from 'daftari-backend-shared/domain/repositories/sale-repository';
import type { SaleStatsDto, SaleStatsResponse } from '../dtos/sale-stats.dto';

export class SaleStatsUseCase {
  constructor(private readonly saleRepo: SaleRepository) {}

  async execute(dto: SaleStatsDto): Promise<SaleStatsResponse> {
    const { tenantId } = dto;
    const isNonEmptyString = (v: unknown): v is string =>
      typeof v === 'string' && v.trim().length > 0;
    if (!isNonEmptyString(tenantId)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }
    const stats = await this.saleRepo.getTenantStats(tenantId);
    return {
      ok: true,
      data: {
        totalSales: stats.saleCount,
        totalRevenue: stats.totalPiastres,
      },
    };
  }
}
