/**
 * Sale List DTOs
 *
 * Data Transfer Objects for the sale list use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */

export interface SaleListDto {
  readonly tenantId: string;
  readonly since: number;
}

export interface SaleListItem {
  readonly id: string;
  readonly tenantId: string;
  readonly totalPiastres: number;
  readonly createdAt: number;
}

export type SaleListResponse =
  | {
      readonly ok: true;
      readonly data: {
        readonly sales: SaleListItem[];
      };
    }
  | {
      readonly ok: false;
      readonly error: 'MISSING_FIELDS';
    };
