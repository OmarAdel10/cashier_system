/** Authenticated identity supplied by a trusted boundary. */
export interface AuthenticatedPrincipal {
  /** Tenant that owns the authenticated session. */
  readonly tenantId: string;
  /** Authenticated session ID, when the boundary binds one. */
  readonly sessionId?: string;
  /** Authenticated username, when the boundary binds one. */
  readonly username?: string;
  /** Authenticated role, when the boundary binds one. */
  readonly role?: string;
}
