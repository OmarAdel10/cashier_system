import 'reflect-metadata';

import { container as rootContainer } from 'tsyringe';
import type { DependencyContainer } from 'tsyringe';
import { TursoDb } from '../turso';
import { AuthServiceImpl } from '../domain/services/auth-service.impl';
import { LicenseServiceImpl } from '../domain/services/license-service';
import { AuthLoginUseCase } from '../application/use-cases/auth-login-use-case';
import { AuthLogoutUseCase } from '../application/use-cases/auth-logout-use-case';
import { SessionEndUseCase } from '../application/use-cases/session-end-use-case';
import { SessionStartUseCase } from '../application/use-cases/session-start-use-case';
import { SyncDataUseCase } from '../application/use-cases/sync-data-use-case';
import { SessionTokenServiceImpl } from '../application/services/session-token-service';
import { MemoryCache } from './cache/memory-cache';
import { CachedLicenseRepository } from './repositories/cached-license-repository';
import { CachedSessionRepository } from './repositories/cached-session-repository';
import { CachedUserRepository } from './repositories/cached-user-repository';
import { TursoAuthUserRepository } from './repositories/turso-auth-user-repository';
import { TursoDeviceRepository } from './repositories/turso-device-repository';
import { TursoLicenseRepository } from './repositories/turso-license-repository';
import { TursoSaleRepository } from './repositories/turso-sale-repository';
import { TursoSessionRepository } from './repositories/turso-session-repository';
import { TursoUserRepository } from './repositories/turso-user-repository';
import { TursoRealtimeTicketRepository } from './repositories/turso-realtime-ticket-repository';
import { DbRateLimiter } from './services/db-rate-limiter';

/** Runtime configuration required by the shared composition root. */
export interface Config {
  /** HS256 secret shared by the API and realtime workers. */
  adminJwtSecret: string;
}

/** String tokens used by decorator and composition-root registrations. */
export const SHARED_TYPES = {
  TursoDb: 'TursoDb',
  MemoryCache: 'MemoryCache',
  TursoAuthUserRepository: 'TursoAuthUserRepository',
  AuthUserRepository: 'AuthUserRepository',
  TursoDeviceRepository: 'TursoDeviceRepository',
  DeviceRepository: 'DeviceRepository',
  TursoLicenseRepository: 'TursoLicenseRepository',
  CachedLicenseRepository: 'CachedLicenseRepository',
  LicenseRepository: 'LicenseRepository',
  TursoSaleRepository: 'TursoSaleRepository',
  SaleRepository: 'SaleRepository',
  TursoSessionRepository: 'TursoSessionRepository',
  CachedSessionRepository: 'CachedSessionRepository',
  SessionRepository: 'SessionRepository',
  TursoUserRepository: 'TursoUserRepository',
  CachedUserRepository: 'CachedUserRepository',
  UserRepository: 'UserRepository',
  TursoRealtimeTicketRepository: 'TursoRealtimeTicketRepository',
  RealtimeTicketRepository: 'RealtimeTicketRepository',
  AuthService: 'AuthService',
  LicenseService: 'LicenseService',
  RateLimiter: 'RateLimiter',
  SessionTokenService: 'SessionTokenService',
  AdminJwtSecret: 'AdminJwtSecret',
  AuthLoginUseCase: 'AuthLoginUseCase',
  AuthLogoutUseCase: 'AuthLogoutUseCase',
  SessionStartUseCase: 'SessionStartUseCase',
  SessionEndUseCase: 'SessionEndUseCase',
  SyncDataUseCase: 'SyncDataUseCase',
} as const;

/**
 * Build an isolated composition root for one worker runtime.
 *
 * Concrete repositories are registered under their own tokens. Cached
 * repositories decorate the concrete repositories, and the generic repository
 * tokens alias the application-facing implementations.
 */
export function createSharedContainer(
  db: TursoDb,
  config: Config,
): DependencyContainer {
  const dependencyContainer = rootContainer.createChildContainer();
  const cache = new MemoryCache<unknown>();

  dependencyContainer.register(SHARED_TYPES.TursoDb, { useValue: db });
  dependencyContainer.register(SHARED_TYPES.MemoryCache, { useValue: cache });
  dependencyContainer.register(SHARED_TYPES.AdminJwtSecret, {
    useValue: config.adminJwtSecret,
  });

  dependencyContainer.registerSingleton(
    SHARED_TYPES.TursoAuthUserRepository,
    TursoAuthUserRepository,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.TursoDeviceRepository,
    TursoDeviceRepository,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.TursoLicenseRepository,
    TursoLicenseRepository,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.TursoSaleRepository,
    TursoSaleRepository,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.TursoSessionRepository,
    TursoSessionRepository,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.TursoUserRepository,
    TursoUserRepository,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.TursoRealtimeTicketRepository,
    TursoRealtimeTicketRepository,
  );

  dependencyContainer.registerSingleton(
    SHARED_TYPES.CachedLicenseRepository,
    CachedLicenseRepository,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.CachedSessionRepository,
    CachedSessionRepository,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.CachedUserRepository,
    CachedUserRepository,
  );

  dependencyContainer.register(SHARED_TYPES.AuthUserRepository, {
    useToken: SHARED_TYPES.TursoAuthUserRepository,
  });
  dependencyContainer.register(SHARED_TYPES.DeviceRepository, {
    useToken: SHARED_TYPES.TursoDeviceRepository,
  });
  dependencyContainer.register(SHARED_TYPES.LicenseRepository, {
    useToken: SHARED_TYPES.CachedLicenseRepository,
  });
  dependencyContainer.register(SHARED_TYPES.SaleRepository, {
    useToken: SHARED_TYPES.TursoSaleRepository,
  });
  dependencyContainer.register(SHARED_TYPES.SessionRepository, {
    useToken: SHARED_TYPES.CachedSessionRepository,
  });
  dependencyContainer.register(SHARED_TYPES.UserRepository, {
    useToken: SHARED_TYPES.CachedUserRepository,
  });

  dependencyContainer.register(SHARED_TYPES.RealtimeTicketRepository, {
    useClass: TursoRealtimeTicketRepository,
  });


  dependencyContainer.register(SHARED_TYPES.AuthService, {
    useValue: new AuthServiceImpl(),
  });
  dependencyContainer.register(SHARED_TYPES.LicenseService, {
    useValue: new LicenseServiceImpl(),
  });
  dependencyContainer.registerSingleton(
    SHARED_TYPES.RateLimiter,
    DbRateLimiter,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.SessionTokenService,
    SessionTokenServiceImpl,
  );

  dependencyContainer.registerSingleton(
    SHARED_TYPES.AuthLoginUseCase,
    AuthLoginUseCase,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.AuthLogoutUseCase,
    AuthLogoutUseCase,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.SessionStartUseCase,
    SessionStartUseCase,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.SessionEndUseCase,
    SessionEndUseCase,
  );
  dependencyContainer.registerSingleton(
    SHARED_TYPES.SyncDataUseCase,
    SyncDataUseCase,
  );

  return dependencyContainer;
}
