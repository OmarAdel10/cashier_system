/**
 * Login DTOs
 *
 * Data Transfer Objects for the login use case.
 * These define the input and output contracts for authentication.
 */

/**
 * Input data for user login.
 */
export interface LoginDto {
  readonly tenantId: string;
  readonly username: string;
  readonly password: string;
  readonly ip: string;
}

/**
 * Output data for successful login.
 */
export interface LoginSuccessData {
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
  };
  readonly license?: {
    readonly tenantId: string;
    readonly deviceHwid: string;
    readonly licenseKey: string;
    readonly subscriptionEnd: number;
    readonly billingCycle: 'monthly' | 'yearly' | 'lifetime';
    readonly graceEnd: number;
    readonly status: 'active' | 'expired';
    readonly createdAt: number;
  };
}

/**
 * Login response type - discriminated union.
 */
export type LoginResponse =
  | {
      readonly ok: true;
      readonly data: LoginSuccessData;
    }
  | {
      readonly ok: false;
      readonly error:
        | 'MISSING_FIELDS'
        | 'RATE_LIMITED'
        | 'BAD_CREDENTIALS'
        | 'ACCOUNT_DISABLED'
        | 'DASHBOARD_ADMIN_ONLY'
        | 'OWNER_REAUTH_REQUIRED'
        | 'SESSION_CONFLICT'
        | 'NO_LICENSE'
        | 'LICENSE_EXPIRED'
        | 'SESSION_CREATION_FAILED'
        | 'USER_PROFILE_NOT_FOUND';
      readonly retryAfterMs?: number;
      readonly lockedUntil?: number;
      readonly conflictSessionId?: string;
    };
