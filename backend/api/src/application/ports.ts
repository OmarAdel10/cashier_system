import type { AuthUserRepository } from '../../../shared/src/domain/repositories/auth-user-repository';
import type { SessionRepository } from '../../../shared/src/domain/repositories/session-repository';
import type { UserRepository } from '../../../shared/src/domain/repositories/user-repository';
import type { SessionTokenService } from '../../../shared/src/application/services/session-token-service';

/** Firebase ID-token verifier used by the API presentation boundary. */
export type FirebaseTokenVerifier = (
  token: string,
  projectId: string,
) => Promise<{
  valid: boolean;
  uid?: string;
  email?: string;
  signInProvider?: string;
  emailVerified?: boolean;
}>;

/** Request-scoped application dependencies resolved by the API runtime. */
export interface AuthApplicationServices {
  readonly sessionRepository: SessionRepository;
  readonly authUserRepository: AuthUserRepository;
  readonly userRepository: UserRepository;
  readonly sessionTokenService: SessionTokenService;
  readonly verifyToken: FirebaseTokenVerifier;
}

/** Application-facing services exposed by the API composition boundary. */
export interface ApiServices {
  readonly auth: AuthApplicationServices;
}

/** Minimal environment shape needed to compose the shared container. */
export interface ApiRuntimeEnv {
  readonly TURSO_DATABASE_URL: string;
  readonly TURSO_AUTH_TOKEN: string;
  readonly ADMIN_JWT_SECRET: string;
  /** Firebase project ID used for ID token verification. */
  readonly FIREBASE_PROJECT_ID: string;
}

export type ApiServicesGetter = (env: ApiRuntimeEnv) => ApiServices;

/** Authenticated identity produced by the application authentication model. */
export interface RequestPrincipal {
  readonly tenantId: string;
  readonly email?: string;
  readonly username?: string;
  readonly role?: string;
  readonly sessionId?: string;
  readonly isOwner: boolean;
}

/** Application-level authentication failures, without HTTP semantics. */
export type RequestAuthenticationFailureCode =
  | 'SESSION_EXPIRED'
  | 'SESSION_REVOKED'
  | 'INVALID_TOKEN'
  | 'INVALID_SIGNATURE'
  | 'PROVIDER_NOT_ALLOWED'
  | 'EMAIL_NOT_VERIFIED';

export type RequestAuthenticationResult =
  | {
      readonly status: 'authenticated';
      readonly principal: RequestPrincipal;
    }
  | {
      readonly status: 'unauthenticated';
      readonly code: RequestAuthenticationFailureCode;
    };
