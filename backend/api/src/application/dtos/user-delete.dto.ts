/**
 * User Delete DTOs
 *
 * Data Transfer Objects for the user delete use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */

export interface UserDeleteDto {
  readonly tenantId: string;
  readonly username: string;
}

export type UserDeleteResponse =
  | {
      readonly ok: true;
    }
  | {
      readonly ok: false;
      readonly error: 'MISSING_FIELDS' | 'USER_NOT_FOUND';
    };
