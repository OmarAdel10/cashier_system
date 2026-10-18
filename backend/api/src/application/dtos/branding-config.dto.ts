/**
 * Branding Config DTOs
 *
 * Data Transfer Objects for the branding config use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */

export interface BrandingConfigDto {
  readonly tenantId: string;
}

export interface BrandingConfigSuccessData {
  readonly primaryColor: string;
  readonly logo?: string;
}

export type BrandingConfigResponse =
  | {
      readonly ok: true;
      readonly data: BrandingConfigSuccessData;
    }
  | {
      readonly ok: false;
      readonly error: 'MISSING_FIELDS' | 'NO_LICENSE';
    };
