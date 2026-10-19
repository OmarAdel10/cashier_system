import { verifyFirebaseToken, FirebaseTokenResult } from 'daftari-backend-shared/jwt';

/**
 * Auth client wrapping Firebase ID token verification.
 *
 * Identity fields come from verified middleware context at the wiring phase;
 * do NOT enforce authz here.
 */
export class AuthClient {
  constructor(private readonly projectId: string) {}

  async verify(token: string): Promise<FirebaseTokenResult> {
    return verifyFirebaseToken(token, this.projectId);
  }
}
