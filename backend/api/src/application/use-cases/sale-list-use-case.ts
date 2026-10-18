/**
 * Sale List Use Case
 *
 * Lists sales for a tenant since a given timestamp. Mirrors GET /sales:
 * returns the sale list, which may be empty, with no error arm triggered by
 * an empty result. Results are capped at 50 (Phase 3 list-active precedent).
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */
import type { SaleRepository } from 'daftari-backend-shared/domain/repositories/sale-repository';
import type { Sale } from 'daftari-backend-shared/domain/entities/sale';
import type {
  SaleListDto,
  SaleListResponse,
  SaleListItem,
} from '../dtos/sale-list.dto';

/** Maximum number of sales returned per list request. */
const SALE_LIST_LIMIT = 50;

export class SaleListUseCase {
  constructor(private readonly saleRepo: SaleRepository) {}

  async execute(dto: SaleListDto): Promise<SaleListResponse> {
    const sales = await this.saleRepo.listByTenantSince(dto.tenantId, dto.since);
    return {
      ok: true,
      data: {
        sales: sales
          .slice(0, SALE_LIST_LIMIT)
          .map((s: Sale): SaleListItem => ({
            id: s.id,
            tenantId: s.tenantId,
            receiptJson: s.receiptJson,
            totalPiastres: s.totalPiastres,
            createdAt: s.createdAt,
          })),
      },
    };
  }
}
