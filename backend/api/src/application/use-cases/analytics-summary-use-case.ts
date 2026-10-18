/**
 * Analytics Summary Use Case
 *
 * Returns aggregate sales analytics for a tenant: total sale count and total
 * revenue in piastres. Gates on an active (non-expired) license for the
 * tenant; returns NO_LICENSE when no license exists or the license has
 * expired. No error arm is triggered by zero sales.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */
import type { SaleRepository } from 'daftari-backend-shared/domain/repositories/sale-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type {
  AnalyticsSummaryDto,
  AnalyticsSummaryResponse,
} from '../dtos/analytics-summary.dto';

export class AnalyticsSummaryUseCase {
  constructor(
    private readonly saleRepo: SaleRepository,
    private readonly licenseRepo: LicenseRepository,
  ) {}

  async execute(dto: AnalyticsSummaryDto): Promise<AnalyticsSummaryResponse> {
    const { tenantId } = dto;
    const isNonEmptyString = (v: unknown): v is string =>
      typeof v === 'string' && v.trim().length > 0;
    if (!isNonEmptyString(tenantId)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }

    const license = await this.licenseRepo.findLatestByTenant(tenantId);
    if (license === null) {
      return { ok: false, error: 'NO_LICENSE' };
    }

    const expired = await this.licenseRepo.isExpired(
      license.graceEnd,
      Date.now(),
    );
    if (expired) {
      return { ok: false, error: 'NO_LICENSE' };
    }

    const stats = await this.saleRepo.getTenantStats(tenantId);
    return {
      ok: true,
      data: {
        totalSales: stats.saleCount,
        totalRevenue: Math.max(0, stats.totalPiastres),
      },
    };
  }
}
