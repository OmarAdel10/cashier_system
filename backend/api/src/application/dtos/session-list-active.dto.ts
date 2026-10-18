/**
 * Session List Active DTOs
 *
 * Data Transfer Objects for the session list-active use case.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */

export interface SessionListActiveDto {
  readonly tenantId: string;
}

export interface SessionListActiveSession {
  readonly sessionId: string;
  readonly username: string;
  readonly source: 'pos' | 'web';
  readonly startedAt: number;
  readonly heartbeatAt: number;
}

export type SessionListActiveResponse =
  | {
      readonly ok: true;
      readonly data: {
        readonly sessions: SessionListActiveSession[];
      };
    }
  | {
      readonly ok: false;
      readonly error: 'SESSION_NOT_FOUND';
    };
