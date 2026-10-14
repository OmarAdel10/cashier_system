/** Barrel export for daftari-backend-shared. */
export * from './types';
export * from './base64';
export * from './password_kdf';
export * from './session_jwt';
export * from './paymob';
export * from './license';
export * from './jwt';
export * from './analytics';
export * from './turso';
export * from './rate_limit';

// Clean-architecture public surface:
export * from './domain/entities/auth-user';
export * from './domain/entities/device';
export * from './domain/entities/license';
export * from './domain/entities/sale';
export * from './domain/entities/session';
export * from './domain/entities/user';
export * from './domain/repositories/auth-user-repository';
export * from './domain/repositories/device-repository';
export * from './domain/repositories/license-repository';
export * from './domain/repositories/sale-repository';
export * from './domain/repositories/session-repository';
export * from './domain/repositories/user-repository';
export * from './domain/services/auth-service';
export * from './domain/services/license-service';
export * from './domain/services/rate-limiter';
export * from './application/dtos/principal';
export * from './application/use-cases/auth-login-use-case';
export * from './application/use-cases/auth-logout-use-case';
export * from './application/use-cases/session-start-use-case';
export * from './application/use-cases/session-end-use-case';
export * from './application/use-cases/sync-data-use-case';
export * from './application/services/session-token-service';
export { createSharedContainer, SHARED_TYPES } from './infrastructure/container';
export type { Config } from './infrastructure/container';
