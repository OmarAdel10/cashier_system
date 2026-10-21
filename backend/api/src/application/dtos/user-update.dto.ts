/**
 * User Update DTOs
 *
 * Data Transfer Objects for the user update use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 *
 * The route hashes the password via hashTagged() (KDF is infrastructure) and
 * passes the resulting scheme-tagged hash as passwordHash.
 */

export interface UserUpdateDto {
  readonly tenantId: string;
  readonly username: string;
  readonly passwordHash?: string;
  readonly displayName?: string | null;
  readonly isActive?: 0 | 1;
}

export type UserUpdateResponse =
  | {
      readonly ok: true;
    }
  | {
      readonly ok: false;
      readonly error: 'MISSING_FIELDS' | 'USER_NOT_FOUND';
    };
