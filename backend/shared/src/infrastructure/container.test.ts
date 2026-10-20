import 'reflect-metadata';

import { describe, expect, it } from 'vitest';
import type { Client } from '@libsql/client';
import { createSharedContainer, SHARED_TYPES } from './container';
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
import {
  createSharedContainer as publicCreateSharedContainer,
  SHARED_TYPES as publicSharedTypes,
} from '../index';

const db = new TursoDb({} as Client);
const config = { adminJwtSecret: 'test-admin-jwt-secret' };

describe('createSharedContainer', () => {
  it('resolves the complete clean-architecture surface', () => {
    const container = createSharedContainer(db, config);

    expect(container.resolve<TursoDb>(SHARED_TYPES.TursoDb)).toBe(db);
    expect(container.resolve(SHARED_TYPES.MemoryCache)).toBeInstanceOf(MemoryCache);
    expect(container.resolve(SHARED_TYPES.AdminJwtSecret)).toBe(config.adminJwtSecret);

    expect(container.resolve(SHARED_TYPES.TursoAuthUserRepository)).toBeInstanceOf(
      TursoAuthUserRepository,
    );
    expect(container.resolve(SHARED_TYPES.TursoDeviceRepository)).toBeInstanceOf(
      TursoDeviceRepository,
    );
    expect(container.resolve(SHARED_TYPES.TursoLicenseRepository)).toBeInstanceOf(
      TursoLicenseRepository,
    );
    expect(container.resolve(SHARED_TYPES.TursoSaleRepository)).toBeInstanceOf(
      TursoSaleRepository,
    );
    expect(container.resolve(SHARED_TYPES.TursoSessionRepository)).toBeInstanceOf(
      TursoSessionRepository,
    );
    expect(container.resolve(SHARED_TYPES.TursoUserRepository)).toBeInstanceOf(
      TursoUserRepository,
    );

    expect(container.resolve(SHARED_TYPES.TursoRealtimeTicketRepository)).toBeInstanceOf(
      TursoRealtimeTicketRepository,
    );

    expect(container.resolve(SHARED_TYPES.AuthService)).toBeInstanceOf(AuthServiceImpl);
    expect(container.resolve(SHARED_TYPES.LicenseService)).toBeInstanceOf(
      LicenseServiceImpl,
    );
    expect(container.resolve(SHARED_TYPES.RateLimiter)).toBeInstanceOf(DbRateLimiter);
    expect(container.resolve(SHARED_TYPES.SessionTokenService)).toBeInstanceOf(
      SessionTokenServiceImpl,
    );

    expect(container.resolve(SHARED_TYPES.AuthLoginUseCase)).toBeInstanceOf(
      AuthLoginUseCase,
    );
    expect(container.resolve(SHARED_TYPES.AuthLogoutUseCase)).toBeInstanceOf(
      AuthLogoutUseCase,
    );
    expect(container.resolve(SHARED_TYPES.SessionStartUseCase)).toBeInstanceOf(
      SessionStartUseCase,
    );
    expect(container.resolve(SHARED_TYPES.SessionEndUseCase)).toBeInstanceOf(
      SessionEndUseCase,
    );
    expect(container.resolve(SHARED_TYPES.SyncDataUseCase)).toBeInstanceOf(
      SyncDataUseCase,
    );
  });

  it('aliases selectors to the intended repository instances', () => {
    const container = createSharedContainer(db, config);
    const cache = container.resolve<MemoryCache<unknown>>(SHARED_TYPES.MemoryCache);

    const tursoSession = container.resolve<TursoSessionRepository>(
      SHARED_TYPES.TursoSessionRepository,
    );
    const cachedSession = container.resolve<CachedSessionRepository>(
      SHARED_TYPES.CachedSessionRepository,
    );
    const sessionSelector = container.resolve(SHARED_TYPES.SessionRepository);

    expect(sessionSelector).toBe(cachedSession);
    expect(cachedSession).not.toBe(tursoSession);
    expect((cachedSession as unknown as { decorated: unknown }).decorated).toBe(
      tursoSession,
    );
    expect((cachedSession as unknown as { cache: unknown }).cache).toBe(cache);

    const tursoLicense = container.resolve<TursoLicenseRepository>(
      SHARED_TYPES.TursoLicenseRepository,
    );
    const cachedLicense = container.resolve<CachedLicenseRepository>(
      SHARED_TYPES.CachedLicenseRepository,
    );
    expect(container.resolve(SHARED_TYPES.LicenseRepository)).toBe(cachedLicense);
    expect((cachedLicense as unknown as { decorated: unknown }).decorated).toBe(
      tursoLicense,
    );
    expect((cachedLicense as unknown as { cache: unknown }).cache).toBe(cache);

    const tursoUser = container.resolve<TursoUserRepository>(
      SHARED_TYPES.TursoUserRepository,
    );
    const cachedUser = container.resolve<CachedUserRepository>(
      SHARED_TYPES.CachedUserRepository,
    );
    expect(container.resolve(SHARED_TYPES.UserRepository)).toBe(cachedUser);
    expect((cachedUser as unknown as { decorated: unknown }).decorated).toBe(tursoUser);
    expect((cachedUser as unknown as { cache: unknown }).cache).toBe(cache);

    expect(container.resolve(SHARED_TYPES.AuthUserRepository)).toBe(
      container.resolve(SHARED_TYPES.TursoAuthUserRepository),
    );
    expect(container.resolve(SHARED_TYPES.DeviceRepository)).toBe(
      container.resolve(SHARED_TYPES.TursoDeviceRepository),
    );
    expect(container.resolve(SHARED_TYPES.SaleRepository)).toBe(
      container.resolve(SHARED_TYPES.TursoSaleRepository),
    );
  });

  it('resolves singleton dependencies without circular construction', () => {
    const container = createSharedContainer(db, config);

    expect(container.resolve(SHARED_TYPES.AuthLoginUseCase)).toBe(
      container.resolve(SHARED_TYPES.AuthLoginUseCase),
    );
    expect(container.resolve(SHARED_TYPES.AuthLogoutUseCase)).toBe(
      container.resolve(SHARED_TYPES.AuthLogoutUseCase),
    );
    expect(container.resolve(SHARED_TYPES.SessionStartUseCase)).toBe(
      container.resolve(SHARED_TYPES.SessionStartUseCase),
    );
    expect(container.resolve(SHARED_TYPES.SessionEndUseCase)).toBe(
      container.resolve(SHARED_TYPES.SessionEndUseCase),
    );
    expect(container.resolve(SHARED_TYPES.SyncDataUseCase)).toBe(
      container.resolve(SHARED_TYPES.SyncDataUseCase),
    );
  });

  it('exposes the composition root through the public package surface', () => {
    expect(publicCreateSharedContainer).toBe(createSharedContainer);
    expect(publicSharedTypes).toBe(SHARED_TYPES);

    const container = publicCreateSharedContainer(db, config);
    const licenseService = container.resolve<LicenseServiceImpl>(
      publicSharedTypes.LicenseService,
    );

    expect(licenseService.isExpired(0, 1)).toBe(false);
    expect(licenseService.isExpired(1, 2)).toBe(true);
    expect(licenseService.getDeviceLimit('business')).toBe(4);
    expect(licenseService.getDeviceLimit('unknown')).toBe(1);
  });
});
