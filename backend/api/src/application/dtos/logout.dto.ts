/**
 * Logout DTOs
 *
 * Data Transfer Objects for the logout use case.
 */

/**
 * Input data for user logout.
 */
export interface LogoutDto {
  readonly sessionId: string;
  readonly tenantId: string;
}

/**
 * Output data for logout.
 */
export interface LogoutResponse {
  readonly ok: true;
} | {
  readonly ok: false;
  readonly error: 'SESSION_NOT_FOUND' | 'INVALID_SESSION';
}
