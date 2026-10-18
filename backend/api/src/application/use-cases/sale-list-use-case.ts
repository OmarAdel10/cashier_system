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
    const { tenantId, since } = dto;
    const now = Date.now();
    const isNonEmptyString = (v: unknown): v is string =>
      typeof v === 'string' && v.trim().length > 0;
    if (!isNonEmptyString(tenantId)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }
    if (
      typeof since !== 'number' ||
      !Number.isFinite(since) ||
      since < 0 ||
      since > now + 60_000
    ) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }
    const sales = await this.saleRepo.listByTenantSince(tenantId, since);
    return {
      ok: true,
      data: {
        sales: sales
          .slice(0, SALE_LIST_LIMIT)
          .map((s: Sale): SaleListItem => ({
            id: s.id,
            tenantId: s.tenantId,
            totalPiastres: s.totalPiastres,
            createdAt: s.createdAt,
          })),
      },
    };
  }
}
