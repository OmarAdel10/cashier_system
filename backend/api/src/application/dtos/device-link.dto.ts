/**
 * Device Link DTOs
 *
 * Data Transfer Objects for the device link use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */

export interface DeviceLinkDto {
  readonly tenantId: string;
  readonly deviceHwid: string;
  readonly deviceName?: string;
  readonly platform?: string;
}

export interface DeviceLinkSuccessData {
  readonly deviceHwid: string;
  readonly device_name: string | null;
  readonly platform: string | null;
  readonly first_seen_at: number;
  readonly last_seen_at: number;
}

export type DeviceLinkResponse =
  | {
      readonly ok: true;
      readonly data: DeviceLinkSuccessData;
    }
  | {
      readonly ok: false;
      readonly error: 'MISSING_FIELDS';
    };
