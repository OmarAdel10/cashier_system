import { verifyFirebaseToken } from 'daftari-backend-shared/jwt';
import {
  createSharedContainer,
  SHARED_TYPES,
} from 'daftari-backend-shared/infrastructure/container';
import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { DeviceRepository } from 'daftari-backend-shared/domain/repositories/device-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { RateLimiter } from 'daftari-backend-shared/domain/services/rate-limiter';
import type { SaleRepository } from 'daftari-backend-shared/domain/repositories/sale-repository';
import type { RealtimeTicketRepository } from 'daftari-backend-shared/domain/repositories/realtime-ticket-repository';
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { SessionTokenService } from 'daftari-backend-shared/application/services/session-token-service';
import type { AuthService } from 'daftari-backend-shared/domain/services/auth-service';
import { AnalyticsClient } from './infrastructure/analytics-client';
import { AuthClient } from './infrastructure/auth-client';
import type { getDb } from './db';
import type {
  ApiRuntimeEnv,
  ApiServices,
  FirebaseTokenVerifier,
} from './application/ports';
import { verifyTagged } from '../../shared/src/password_kdf';
import { DashboardLoginUseCase } from './application/use-cases/dashboard-login-use-case';
import { DashboardLogoutUseCase } from './application/use-cases/dashboard-logout-use-case';
import { OwnerRefreshUseCase } from './application/use-cases/owner-refresh-use-case';
import { AuthSessionResumeUseCase } from './application/use-cases/auth-session-resume-use-case';
import { GetAuthProfileUseCase } from './application/use-cases/get-auth-profile-use-case';
import { SyncFirebaseUserUseCase } from './application/use-cases/sync-firebase-user-use-case';
import { IssueRealtimeTicketUseCase } from './application/use-cases/issue-realtime-ticket-use-case';
import { ValidateRealtimeTicketUseCase } from './application/use-cases/validate-realtime-ticket-use-case';
import { SessionStartUseCase } from './application/use-cases/session-start-use-case';
import { SessionHeartbeatUseCase } from './application/use-cases/session-heartbeat-use-case';
import { SessionEndUseCase } from './application/use-cases/session-end-use-case';
import { SessionListActiveUseCase } from './application/use-cases/session-list-active-use-case';
import { SaleRecordUseCase } from './application/use-cases/sale-record-use-case';
import { SaleListUseCase } from './application/use-cases/sale-list-use-case';
import { AdminSettingsUseCase } from './application/use-cases/admin-settings-use-case';
import { UserListUseCase } from './application/use-cases/user-list-use-case';
import { UserCreateUseCase } from './application/use-cases/user-create-use-case';
import { UserUpdateUseCase } from './application/use-cases/user-update-use-case';
import { UserDeleteUseCase } from './application/use-cases/user-delete-use-case';
import { DeviceLinkUseCase } from './application/use-cases/device-link-use-case';

interface ApiRuntimeOptions {
  readonly getDb: typeof getDb;
  readonly verifyToken?: FirebaseTokenVerifier;
  readonly verify?: typeof verifyTagged;
}

/**
 * Creates the API's composition boundary.
 *
 * Each app instance lazily creates one isolated shared container. Only the
 * resolved application-facing services are exposed; neither the container nor
 * TursoDb escapes this boundary.
 */
export function createApiRuntime(options: ApiRuntimeOptions) {
  let services: ApiServices | null = null;

  return {
    getServices(env: ApiRuntimeEnv): ApiServices {
      if (!services) {
        // Required API credentials must be present before composing the
        // container; fail fast at composition time rather than failing a
        // request later with an opaque error.
        if (!env.POSTHOG_API_KEY || !env.FIREBASE_PROJECT_ID || !env.ADMIN_JWT_SECRET) {
          throw new Error('required API credentials are not configured');
        }

        const container = createSharedContainer(options.getDb(env), {
          adminJwtSecret: env.ADMIN_JWT_SECRET,
        });

        // Resolve all repositories first — use case construction below
        // depends on them, and they must not reference services.auth (which
        // is still being built).
        const sessionRepository = container.resolve<SessionRepository>(
          SHARED_TYPES.TursoSessionRepository,
        );
        const authUserRepository = container.resolve<AuthUserRepository>(
          SHARED_TYPES.AuthUserRepository,
        );
        const userRepository = container.resolve<UserRepository>(
          SHARED_TYPES.TursoUserRepository,
        );
        const sessionTokenService = container.resolve<SessionTokenService>(
          SHARED_TYPES.SessionTokenService,
        );
        const authService = container.resolve<AuthService>(
          SHARED_TYPES.AuthService,
        );
        const licenseRepository = container.resolve<LicenseRepository>(
          SHARED_TYPES.LicenseRepository,
        );
        const deviceRepository = container.resolve<DeviceRepository>(
          SHARED_TYPES.DeviceRepository,
        );
        const rateLimiter = container.resolve<RateLimiter>(
          SHARED_TYPES.RateLimiter,
        );
        const saleRepository = container.resolve<SaleRepository>(
          SHARED_TYPES.SaleRepository,
        );
        const realtimeTicketRepository = container.resolve<RealtimeTicketRepository>(
          SHARED_TYPES.RealtimeTicketRepository,
        );

        const auth = Object.freeze({
          sessionRepository,
          authUserRepository,
          userRepository,
          sessionTokenService,
          verifyToken: options.verifyToken ?? verifyFirebaseToken,
          authService,
          licenseRepository,
          deviceRepository,
          rateLimiter,
          saleRepository,
          realtimeTicketRepository,
          // Application-layer use cases — constructed here so route wiring
          // in index.ts only delegates to pre-built use cases.
          dashboardLogin: new DashboardLoginUseCase(
            authUserRepository,
            sessionRepository,
            licenseRepository,
            userRepository,
            authService,
            rateLimiter,
            sessionTokenService,
            env.ADMIN_JWT_SECRET,
            options.verify ?? verifyTagged,
          ),
          dashboardLogout: new DashboardLogoutUseCase(sessionRepository),
          ownerRefresh: new OwnerRefreshUseCase(userRepository),
          sessionResume: new AuthSessionResumeUseCase(
            sessionTokenService,
            userRepository,
            env.ADMIN_JWT_SECRET,
          ),
          getAuthProfile: new GetAuthProfileUseCase(
            userRepository,
            licenseRepository,
          ),
          syncFirebaseUser: new SyncFirebaseUserUseCase(
            userRepository,
            licenseRepository,
          ),
          issueRealtimeTicket: new IssueRealtimeTicketUseCase(
            userRepository,
            realtimeTicketRepository,
          ),
          validateRealtimeTicket: new ValidateRealtimeTicketUseCase(
            realtimeTicketRepository,
          ),
          sessionStart: new SessionStartUseCase(
            sessionRepository,
            deviceRepository,
            licenseRepository,
            authUserRepository,
            userRepository,
            sessionTokenService,
            env.ADMIN_JWT_SECRET,
          ),
          sessionHeartbeat: new SessionHeartbeatUseCase(sessionRepository),
          sessionEnd: new SessionEndUseCase(sessionRepository),
          sessionListActive: new SessionListActiveUseCase(sessionRepository),
          saleRecord: new SaleRecordUseCase(
            saleRepository,
            deviceRepository,
            licenseRepository,
            userRepository,
          ),
          saleList: new SaleListUseCase(saleRepository),
          adminSettings: new AdminSettingsUseCase(
            userRepository,
            licenseRepository,
          ),
          userList: new UserListUseCase(authUserRepository),
          userCreate: new UserCreateUseCase(
            authUserRepository,
            userRepository,
          ),
          userUpdate: new UserUpdateUseCase(authUserRepository),
          userDelete: new UserDeleteUseCase(authUserRepository),
          deviceLink: new DeviceLinkUseCase(deviceRepository),
        });

        const analyticsClient = new AnalyticsClient(env.POSTHOG_API_KEY);
        const authClient = new AuthClient(env.FIREBASE_PROJECT_ID);

        services = Object.freeze({
          auth,
          analytics: analyticsClient,
          authClient,
          rateLimiter,
        });
      }

      return services!;
    },
  };
}
