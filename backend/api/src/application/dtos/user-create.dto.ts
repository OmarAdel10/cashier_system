/**
 * User Create DTOs
 *
 * Data Transfer Objects for the user create use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 *
 * The route hashes the password via hashTagged() (KDF is infrastructure) and
 * passes the resulting scheme-tagged hash as passwordHash.
 */

export interface UserCreateDto {
  readonly tenantId: string;
  readonly username: string;
  readonly passwordHash: string;
  readonly role: 'admin' | 'cashier';
  readonly displayName?: string;
  readonly isOwner: boolean;
}

export interface UserCreateSuccessData {
  readonly username: string;
  readonly role: 'admin' | 'cashier';
  readonly display_name?: string;
}

export type UserCreateResponse =
  | {
      readonly ok: true;
      readonly data: UserCreateSuccessData;
    }
  | {
      readonly ok: false;
      readonly error:
        | 'MISSING_FIELDS'
        | 'TIER_REQUIRED'
        | 'ADMIN_MANAGEMENT_OWNER_ONLY'
        | 'USERNAME_TAKEN';
    };
