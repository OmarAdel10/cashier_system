import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { DeviceRepository } from 'daftari-backend-shared/domain/repositories/device-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { SaleRepository } from 'daftari-backend-shared/domain/repositories/sale-repository';
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { RealtimeTicketRepository } from 'daftari-backend-shared/domain/repositories/realtime-ticket-repository';
import type { SessionTokenService } from 'daftari-backend-shared/application/services/session-token-service';
import type { RateLimiter } from 'daftari-backend-shared/domain/services/rate-limiter';
import type { AuthService } from 'daftari-backend-shared/domain/services/auth-service';
import type { PostHogEvent, BatchResult } from 'daftari-backend-shared/analytics';
import type { FirebaseTokenResult } from 'daftari-backend-shared/jwt';
import { verifyFirebaseToken } from 'daftari-backend-shared/jwt';
import type { verifyTagged } from 'daftari-backend-shared/password_kdf';
import type { DashboardLoginUseCase } from './use-cases/dashboard-login-use-case';
import type { DashboardLogoutUseCase } from './use-cases/dashboard-logout-use-case';
import type { OwnerRefreshUseCase } from './use-cases/owner-refresh-use-case';
import type { AuthSessionResumeUseCase } from './use-cases/auth-session-resume-use-case';
import type { GetAuthProfileUseCase } from './use-cases/get-auth-profile-use-case';
import type { SyncFirebaseUserUseCase } from './use-cases/sync-firebase-user-use-case';
import type { IssueRealtimeTicketUseCase } from './use-cases/issue-realtime-ticket-use-case';
import type { ValidateRealtimeTicketUseCase } from './use-cases/validate-realtime-ticket-use-case';
import type { SessionStartUseCase } from './use-cases/session-start-use-case';
import type { SessionHeartbeatUseCase } from './use-cases/session-heartbeat-use-case';
import type { SessionEndUseCase } from './use-cases/session-end-use-case';
import type { SessionListActiveUseCase } from './use-cases/session-list-active-use-case';
import type { SaleRecordUseCase } from './use-cases/sale-record-use-case';
import type { SaleListUseCase } from './use-cases/sale-list-use-case';
import type { AdminSettingsUseCase } from './use-cases/admin-settings-use-case';
import type { UserListUseCase } from './use-cases/user-list-use-case';
import type { UserCreateUseCase } from './use-cases/user-create-use-case';
import type { UserUpdateUseCase } from './use-cases/user-update-use-case';
import type { UserDeleteUseCase } from './use-cases/user-delete-use-case';
import type { DeviceLinkUseCase } from './use-cases/device-link-use-case';

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
  readonly authService: AuthService;
  readonly licenseRepository: LicenseRepository;
  readonly deviceRepository: DeviceRepository;
  readonly saleRepository: SaleRepository;
  readonly realtimeTicketRepository: RealtimeTicketRepository;
  readonly rateLimiter: RateLimiter;
  readonly dashboardLogin: DashboardLoginUseCase;
  readonly dashboardLogout: DashboardLogoutUseCase;
  readonly ownerRefresh: OwnerRefreshUseCase;
  readonly sessionResume: AuthSessionResumeUseCase;
  readonly getAuthProfile: GetAuthProfileUseCase;
  readonly syncFirebaseUser: SyncFirebaseUserUseCase;
  readonly issueRealtimeTicket: IssueRealtimeTicketUseCase;
  readonly validateRealtimeTicket: ValidateRealtimeTicketUseCase;
  readonly sessionStart: SessionStartUseCase;
  readonly sessionHeartbeat: SessionHeartbeatUseCase;
  readonly sessionEnd: SessionEndUseCase;
  readonly sessionListActive: SessionListActiveUseCase;
  readonly saleRecord: SaleRecordUseCase;
  readonly saleList: SaleListUseCase;
  readonly adminSettings: AdminSettingsUseCase;
  readonly userList: UserListUseCase;
  readonly userCreate: UserCreateUseCase;
  readonly userUpdate: UserUpdateUseCase;
  readonly userDelete: UserDeleteUseCase;
  readonly deviceLink: DeviceLinkUseCase;
}

/** Application-facing services exposed by the API composition boundary. */
export interface ApiServices {
  readonly auth: AuthApplicationServices;
  readonly analytics: AnalyticsClient;
  readonly authClient: AuthClient;
  readonly rateLimiter: RateLimiter;
}

export interface ApiRuntimeEnv {
  readonly TURSO_DATABASE_URL: string;
  readonly TURSO_AUTH_TOKEN: string;
  readonly ADMIN_JWT_SECRET: string;
  /** Firebase project ID used for ID token verification. */
  readonly FIREBASE_PROJECT_ID: string;
  /** PostHog API key for server-side batched analytics. */
  readonly POSTHOG_API_KEY: string;
  /** Firebase token verifier for auth. */
  readonly verifyToken: FirebaseTokenVerifier;
  /** KDF verifier for auth. */
  readonly verify: typeof verifyTagged;
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