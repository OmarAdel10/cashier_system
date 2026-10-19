/**
 * Admin Settings DTOs
 *
 * Data Transfer Objects for the admin settings use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */

export interface AdminSettingsDto {
  readonly tenantId: string;
}

export interface AdminSettingsSuccessData {
  readonly tier: string;
  readonly deviceLimit: number;
  readonly licenseStatus: 'active' | 'expired';
}

export type AdminSettingsResponse =
  | {
      readonly ok: true;
      readonly data: AdminSettingsSuccessData;
    }
  | {
      readonly ok: false;
      readonly error: 'MISSING_FIELDS' | 'USER_NOT_FOUND' | 'NO_LICENSE';
    };
