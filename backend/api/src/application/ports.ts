import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { DeviceRepository } from 'daftari-backend-shared/domain/repositories/device-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { SaleRepository } from 'daftari-backend-shared/domain/repositories/sale-repository';
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { SessionTokenService } from 'daftari-backend-shared/application/services/session-token-service';
import type { RateLimiter } from 'daftari-backend-shared/domain/services/rate-limiter';
import type { PostHogEvent, BatchResult } from 'daftari-backend-shared/analytics';
import type { FirebaseTokenResult } from 'daftari-backend-shared/jwt';

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
  readonly licenseRepository: LicenseRepository;
  readonly deviceRepository: DeviceRepository;
  readonly saleRepository: SaleRepository;
}

/** Application-facing services exposed by the API composition boundary. */
export interface ApiServices {
  readonly auth: AuthApplicationServices;
  readonly analytics: AnalyticsClient;
  readonly authClient: AuthClient;
  readonly rateLimiter: RateLimiter;
}

/** Minimal environment shape needed to compose the shared container. */
export interface ApiRuntimeEnv {
  readonly TURSO_DATABASE_URL: string;
  readonly TURSO_AUTH_TOKEN: string;
  readonly ADMIN_JWT_SECRET: string;
  /** Firebase project ID used for ID token verification. */
  readonly FIREBASE_PROJECT_ID: string;
  /** PostHog API key for server-side batched analytics. */
  readonly POSTHOG_API_KEY: string;
}

/**
 * Analytics client interface. Wraps PostHog batching; identity fields are
 * sourced from verified middleware context at the wiring phase, not enforced
 * here. Authz is a later-phase concern.
 */
export interface AnalyticsClient {
  batch(events: PostHogEvent[]): Promise<BatchResult>;
}

/**
 * Auth client interface. Wraps Firebase ID token verification; identity fields
 * come from verified middleware context at the wiring phase; do NOT enforce
 * authz here.
 */
export interface AuthClient {
  verify(token: string): Promise<FirebaseTokenResult>;
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
