/**
 * Session Revoke DTOs
 *
 * Data Transfer Objects for the session revoke use case.
 *
 * Wiring precondition (doc): identity fields (sessionId, tenantId) must be
 * sourced ONLY from verified middleware context at the wiring phase - never
 * from request body/query/header. Application layer trusts DTO input by
 * design; authz is a Phases 7-12 concern.
 */

export interface SessionRevokeDto {
  readonly sessionId: string;
  readonly tenantId: string;
}

export type SessionRevokeResponse =
  | {
      readonly ok: true;
    }
  | {
      readonly ok: false;
      readonly error: 'SESSION_NOT_FOUND' | 'OWNER_ONLY';
    };
