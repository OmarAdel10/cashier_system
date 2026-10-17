import { verifyFirebaseToken } from 'daftari-backend-shared/jwt';
import {
  createSharedContainer,
  SHARED_TYPES,
} from 'daftari-backend-shared/infrastructure/container';
import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { SessionTokenService } from 'daftari-backend-shared/application/services/session-token-service';
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
          verifyToken: options.verifyToken ?? verifyFirebaseToken,
        });

        services = Object.freeze({ auth });
      }

      return services;
    },
  };
}
