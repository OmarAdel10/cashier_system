import { describe, expect, it, vi } from 'vitest';
import type { TursoDb } from 'daftari-backend-shared/turso';
import { createApiRuntime } from '../src/runtime';

const env = {
  TURSO_DATABASE_URL: 'https://test.turso.io',
  TURSO_AUTH_TOKEN: 'turso-token',
  ADMIN_JWT_SECRET: 'test-admin-jwt-secret',
  FIREBASE_PROJECT_ID: 'test-project',
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
    expect(Object.keys(first)).toEqual(['auth']);
    expect(first).not.toHaveProperty('db');
    expect(first).not.toHaveProperty('container');
    expect(first).not.toHaveProperty('TursoDb');
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
});
