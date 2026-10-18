/**
 * Analytics Summary DTOs
 *
 * Data Transfer Objects for the analytics summary use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */

export interface AnalyticsSummaryDto {
  readonly tenantId: string;
}

export interface AnalyticsSummarySuccessData {
  readonly totalSales: number;
  readonly totalRevenue: number;
}

export type AnalyticsSummaryResponse =
  | {
      readonly ok: true;
      readonly data: AnalyticsSummarySuccessData;
    }
  | {
      readonly ok: false;
      readonly error: 'MISSING_FIELDS' | 'NO_LICENSE';
    };
