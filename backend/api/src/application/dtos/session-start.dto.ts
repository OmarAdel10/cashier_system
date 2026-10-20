/**
 * Session Start DTOs
 *
 * Data Transfer Objects for the session start use case.
 *
 * Wiring precondition (doc): identity fields (tenantId, deviceHwid, username,
 * source) must be sourced ONLY from verified middleware context at the wiring
 * phase - never from request body/query/header. Application layer trusts DTO
 * input by design; authz is a Phases 7-12 concern.
 */

import type { SessionListActiveSession } from './session-list-active.dto';

export interface SessionStartDto {
  readonly tenantId: string;
  readonly deviceHwid: string;
  readonly username: string;
  readonly source: 'pos' | 'web';
}

export interface SessionStartSuccessData {
  readonly sessionId: string;
  readonly token: string;
}

export type SessionStartResponse =
  | {
      readonly ok: true;
      readonly data: SessionStartSuccessData;
    }
  | {
      readonly ok: false;
      readonly error:
        | 'MISSING_FIELDS'
        | 'USER_NOT_FOUND'
        | 'ACCOUNT_DISABLED'
        | 'NO_LICENSE'
        | 'LICENSE_EXPIRED'
        | 'DEVICE_LIMIT_EXCEEDED'
        | 'SESSION_CREATION_FAILED';
      readonly activeSessions?: SessionListActiveSession[];
    };
