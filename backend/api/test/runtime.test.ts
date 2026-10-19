import { describe, expect, it, vi } from 'vitest';
import type { TursoDb } from 'daftari-backend-shared/turso';
import { createApiRuntime } from '../src/runtime';

const env = {
  TURSO_DATABASE_URL: 'https://test.turso.io',
  TURSO_AUTH_TOKEN: 'turso-token',
  ADMIN_JWT_SECRET: 'test-admin-jwt-secret',
  FIREBASE_PROJECT_ID: 'test-project',
  POSTHOG_API_KEY: 'test-posthog-key',
};

describe('API runtime composition boundary', () => {
  it('lazily builds one frozen service object per runtime', () => {
    const getDb = vi.fn(() => ({}) as TursoDb);
    const runtime = createApiRuntime({ getDb });

    expect(getDb).not.toHaveBeenCalled();

    const first = runtime.getServices(env);
    const second = runtime.getServices(env);

    expect(second).toBe(first);
    expect(getDb).toHaveBeenCalledTimes(1);
    expect(Object.keys(first)).toEqual([
      'auth',
      'analytics',
      'authClient',
      'rateLimiter',
    ]);
    expect(first).not.toHaveProperty('db');
    expect(first).not.toHaveProperty('container');
    expect(first).not.toHaveProperty('TursoDb');

    // New application repositories are wired into AuthApplicationServices.
    expect(first.auth.licenseRepository).toBeDefined();
    expect(first.auth.deviceRepository).toBeDefined();
    expect(first.auth.saleRepository).toBeDefined();

    // New external-service clients are exposed on ApiServices.
    expect(first.analytics).toBeDefined();
    expect(typeof first.analytics.batch).toBe('function');
    expect(first.authClient).toBeDefined();
    expect(typeof first.authClient.verify).toBe('function');
    expect(first.rateLimiter).toBeDefined();
    expect(typeof first.rateLimiter.checkLimit).toBe('function');
    expect(typeof first.rateLimiter.recordAttempt).toBe('function');
  });

  it('builds isolated services for separate app runtimes', () => {
    const firstRuntime = createApiRuntime({
      getDb: () => ({}) as TursoDb,
    });
    const secondRuntime = createApiRuntime({
      getDb: () => ({}) as TursoDb,
    });

    expect(firstRuntime.getServices(env)).not.toBe(secondRuntime.getServices(env));
  });

  it('uses the injected verifyToken when provided, otherwise verifyFirebaseToken', async () => {
    const injectedVerify = vi.fn().mockResolvedValue({
      valid: true,
      uid: 'injected-uid',
    } as any);
    const runtime = createApiRuntime({
      getDb: () => ({}) as TursoDb,
      verifyToken: injectedVerify,
    });

    const services = runtime.getServices(env);
    expect(services.auth.verifyToken).toBe(injectedVerify);

    const defaultRuntime = createApiRuntime({
      getDb: () => ({}) as TursoDb,
    });
    const defaultServices = defaultRuntime.getServices(env);
    expect(defaultServices.auth.verifyToken).not.toBe(injectedVerify);
  });

  it('constructs clients with the configured credentials', () => {
    const runtime = createApiRuntime({ getDb: () => ({}) as TursoDb });
    const services = runtime.getServices(env);

    expect(services.analytics).toBeDefined();
    expect(services.authClient).toBeDefined();
    expect(typeof services.analytics.batch).toBe('function');
    expect(typeof services.authClient.verify).toBe('function');
  });

  it('throws when POSTHOG_API_KEY is missing', () => {
    const runtime = createApiRuntime({ getDb: () => ({}) as TursoDb });
    const badEnv = { ...env, POSTHOG_API_KEY: '' };
    expect(() => runtime.getServices(badEnv)).toThrow(
      'POSTHOG_API_KEY and FIREBASE_PROJECT_ID must be configured',
    );
  });

  it('throws when FIREBASE_PROJECT_ID is missing', () => {
    const runtime = createApiRuntime({ getDb: () => ({}) as TursoDb });
    const badEnv = { ...env, FIREBASE_PROJECT_ID: '' };
    expect(() => runtime.getServices(badEnv)).toThrow(
      'POSTHOG_API_KEY and FIREBASE_PROJECT_ID must be configured',
    );
  });
});
