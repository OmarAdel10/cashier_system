import { injectable } from 'tsyringe';
import { mintSessionJwt, verifySessionJwt } from '../../session_jwt';
import type { SessionClaims } from '../../session_jwt';

/** Signs and verifies the admin session JWT through the audited HS256 codec. */
export interface SessionTokenService {
  mint(claims: SessionClaims, secret: string): Promise<string>;
  verify(token: string, secret: string): Promise<SessionClaims | null>;
}

@injectable()
export class SessionTokenServiceImpl implements SessionTokenService {
  mint(claims: SessionClaims, secret: string): Promise<string> {
    return mintSessionJwt(claims, secret);
  }

  verify(token: string, secret: string): Promise<SessionClaims | null> {
    return verifySessionJwt(token, secret);
  }
}
