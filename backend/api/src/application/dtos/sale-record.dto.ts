/**
 * Sale Record DTOs
 *
 * Data Transfer Objects for the sale record use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */

export interface SaleRecordDto {
  readonly tenantId: string;
  readonly deviceHwid: string;
  readonly receiptJson: string;
  readonly totalPiastres: number;
  readonly createdAt: number;
}

export interface SaleRecordSuccessData {
  readonly saleId: string;
}

export type SaleRecordResponse =
  | {
      readonly ok: true;
      readonly data: SaleRecordSuccessData;
    }
  | {
      readonly ok: false;
      readonly error:
        | 'MISSING_FIELDS'
        | 'USER_NOT_FOUND'
        | 'ACCOUNT_DISABLED'
        | 'NO_LICENSE'
        | 'LICENSE_EXPIRED'
        | 'DEVICE_LIMIT_EXCEEDED'
        | 'SALE_RECORD_FAILED';
    };
