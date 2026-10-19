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
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { SessionTokenService } from 'daftari-backend-shared/application/services/session-token-service';
import { AnalyticsClient } from './infrastructure/analytics-client';
import { AuthClient } from './infrastructure/auth-client';
import type { getDb } from './db';
import type {
  ApiRuntimeEnv,
  ApiServices,
  FirebaseTokenVerifier,
} from './application/ports';

interface ApiRuntimeOptions {
  readonly getDb: typeof getDb;
  readonly verifyToken?: FirebaseTokenVerifier;
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
        const container = createSharedContainer(options.getDb(env), {
          adminJwtSecret: env.ADMIN_JWT_SECRET,
        });

        const auth = Object.freeze({
          // Auth liveness must observe an immediate revocation. The shared
          // cached repository intentionally serves 30-second reads, so the
          // runtime resolves the uncached shared implementation here while
          // still exposing only the repository interface to the API.
          sessionRepository: container.resolve<SessionRepository>(
            SHARED_TYPES.TursoSessionRepository,
          ),
          authUserRepository: container.resolve<AuthUserRepository>(
            SHARED_TYPES.AuthUserRepository,
          ),
          userRepository: container.resolve<UserRepository>(
            SHARED_TYPES.TursoUserRepository,
          ),
          sessionTokenService: container.resolve<SessionTokenService>(
            SHARED_TYPES.SessionTokenService,
          ),
          // Injected verifyToken (or default verifyFirebaseToken) must enforce
          // project/audience on the Firebase ID token; callers must not pass a
          // bypass verifier. Authz (tenant ownership/role checks) is deferred
          // to Phases 7-12 and is not enforced here.
          verifyToken: options.verifyToken ?? verifyFirebaseToken,
          licenseRepository: container.resolve<LicenseRepository>(
            SHARED_TYPES.LicenseRepository,
          ),
          deviceRepository: container.resolve<DeviceRepository>(
            SHARED_TYPES.DeviceRepository,
          ),
          saleRepository: container.resolve<SaleRepository>(
            SHARED_TYPES.SaleRepository,
          ),
        });

        // Required API credentials must be present before clients are handed
        // out; fail fast at composition time rather than failing a request
        // later with an opaque error.
        if (!env.POSTHOG_API_KEY || !env.FIREBASE_PROJECT_ID) {
          throw new Error(
            'POSTHOG_API_KEY and FIREBASE_PROJECT_ID must be configured',
          );
        }

        const analyticsClient = new AnalyticsClient(env.POSTHOG_API_KEY);
        const authClient = new AuthClient(env.FIREBASE_PROJECT_ID);
        const rateLimiter = container.resolve<RateLimiter>(
          SHARED_TYPES.RateLimiter,
        );

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
