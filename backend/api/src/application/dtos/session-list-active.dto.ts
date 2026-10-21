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
  /** Optional display cap (slice from the newest query order). Omit for
   *  callers that must observe the complete live list (revoke, ownership
   *  lookups). */
  readonly limit?: number;
}

export interface SessionListActiveSession {
  readonly sessionId: string;
  readonly username: string;
  readonly source: 'pos' | 'web' | null;
  readonly startedAt: number;
  readonly heartbeatAt: number;
  readonly deviceHwid?: string;
  readonly endedAt?: number;
}

export type SessionListActiveResponse =
  | {
      readonly ok: true;
      readonly data: {
        readonly sessions: SessionListActiveSession[];
      };
    };
