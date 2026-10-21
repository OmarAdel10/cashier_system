/**
 * Sale Stats DTOs
 *
 * Data Transfer Objects for the sale stats use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */

export interface SaleStatsDto {
  readonly tenantId: string;
}

export interface SaleStatsSuccessData {
  readonly totalSales: number;
  readonly totalRevenue: number; // piastres (1/100 currency unit)
}

export type SaleStatsResponse =
  | {
      readonly ok: true;
      readonly data: SaleStatsSuccessData;
    }
  | {
      readonly ok: false;
      readonly error: 'MISSING_FIELDS';
    };
