/**
 * Session Resume DTOs
 *
 * Data Transfer Objects for the session resume use case.
 */

/**
 * Input data for session resume.
 */
export interface SessionResumeDto {
  readonly sessionId: string;
  readonly tenantId: string;
  readonly username: string;
  readonly role: string;
}

/**
 * Output data for session resume.
 */
export type SessionResumeResponse =
  | {
      readonly ok: true;
      readonly data: {
        readonly token: string;
        readonly sessionId: string;
        readonly profile: {
          readonly tenantId: string;
          readonly email: string;
          readonly role: string;
          readonly tier?: string;
          readonly displayName?: string;
          readonly createdAt: number;
          readonly lastLoginAt?: number;
          readonly lastOwnerLoginAt?: number;
        } | null;
      };
    }
  | {
      readonly ok: false;
      readonly error: 'SESSION_REVOKED';
    };
