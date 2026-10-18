/**
 * User List DTOs
 *
 * Data Transfer Objects for the user list use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */

export interface UserListDto {
  readonly tenantId: string;
}

export interface UserListItem {
  readonly id: string;
  readonly username: string;
  readonly role: string;
  readonly displayName?: string;
  readonly isActive: number;
}

export type UserListResponse =
  | {
      readonly ok: true;
      readonly data: {
        readonly users: UserListItem[];
      };
    }
  | {
      readonly ok: false;
      readonly error: 'MISSING_FIELDS';
    };
