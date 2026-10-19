import { verifyFirebaseToken, FirebaseTokenResult } from 'daftari-backend-shared/jwt';

/**
 * Auth client wrapping Firebase ID token verification.
 *
 * Identity fields come from verified middleware context at the wiring phase;
 * do NOT enforce authz here.
 *
 * `verifyFirebaseToken` never throws: on any failure (malformed JWT, bad
 * signature, unreachable JWKS) it returns `{ valid: false, code: ... }`.
 * Callers should inspect `result.valid` rather than wrapping `verify` in
 * try/catch; rejection propagation is retained only for unexpected
 * programming errors in the shared package.
 */
export class AuthClient {
  constructor(private readonly projectId: string) {}

  async verify(token: string): Promise<FirebaseTokenResult> {
    return verifyFirebaseToken(token, this.projectId);
  }
}
