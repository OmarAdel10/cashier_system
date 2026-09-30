/**
 * daftari-api — the single authenticated HTTP surface for Daftari POS.
 *
 * Routes: /auth/*, /sessions/*, /sales/*, /admin/*, /events, /branding/*
 * Cron: daily license-expiry sweep (03:00 UTC).
 */
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import type { Env, Vars } from './env';
import { getDb } from './db';
import type { VerifyTokenFn } from './middleware/auth';
import { registerAuth } from './routes/auth';
import { registerSessions } from './routes/sessions';
import { registerSales } from './routes/sales';
import { registerAdmin } from './routes/admin';
import { registerUsers } from './routes/users';
import { registerAnalytics } from './routes/analytics';
import { registerBranding } from './routes/branding';
import type { FetchFn } from '../../shared/src/types';
import type { verifyTagged } from '../../shared/src/password_kdf';

export interface ApiDeps {
  verifyToken?: VerifyTokenFn;
  getDb?: typeof getDb;
  postHogFetch?: FetchFn;
  /** Injectable KDF verifier (T16): lets a test assert the derivation runs
   *  even for an unknown username. Defaults to the real verifyTagged. */
  verify?: typeof verifyTagged;
}

/** Dashboard origin served by the paired admin_host worker in each
 *  environment (admin_host/wrangler.toml: admin-dev / admin-staging / admin). */
const ADMIN_ORIGINS: Record<string, string> = {
  development: 'https://admin-dev.daftariapp.workers.dev',
  staging: 'https://admin-staging.daftariapp.workers.dev',
  production: 'https://admin.daftariapp.workers.dev',
};

/** The single browser origin allowed to call the api for a given
 *  ENVIRONMENT. Unknown environments get no origin (deny by default). */
export function adminOriginFor(environment: string | undefined): string | null {
  return (environment && ADMIN_ORIGINS[environment]) || null;
}

/** Resolves the CORS allowlist for a request origin: the environment's admin
 *  origin, plus localhost ONLY in development (T19). */
export function allowedCorsOrigin(
  origin: string,
  environment: string | undefined,
): string | null {
  if (!origin) return null;
  if (environment === 'development' && isLocalhostOrigin(origin)) return origin;
  return adminOriginFor(environment) === origin ? origin : null;
}

function isLocalhostOrigin(origin: string): boolean {
  try {
    const { hostname, protocol } = new URL(origin);
    return (
      (hostname === 'localhost' || hostname === '127.0.0.1') &&
      (protocol === 'http:' || protocol === 'https:')
    );
  } catch {
    return false;
  }
}

export function createApp(deps: ApiDeps = {}) {
  const get = deps.getDb ?? getDb;
  const app = new Hono<{ Bindings: Env; Variables: Vars }>();

  // Explicit allowlist (T19) — never a wide-open wildcard. The origin is
  // resolved per request from ENVIRONMENT so dev/staging/production each only
  // echo their own admin_host origin.
  app.use(
    '*',
    cors({
      origin: (origin, c) => allowedCorsOrigin(origin, c.env.ENVIRONMENT),
      allowHeaders: ['Authorization', 'Content-Type'],
    }),
  );

  app.get('/health', (c) => c.json({ ok: true, env: c.env.ENVIRONMENT ?? 'unknown' }));

  registerAuth(app, {
    verifyToken: deps.verifyToken,
    getDb: get,
    verify: deps.verify,
  });
  registerSessions(app, { verifyToken: deps.verifyToken, getDb: get });
  registerSales(app, { verifyToken: deps.verifyToken, getDb: get });
  registerAdmin(app, { verifyToken: deps.verifyToken, getDb: get });
  // After registerAdmin: the /admin/* requireAuth middleware covers these.
  registerUsers(app, { verifyToken: deps.verifyToken, getDb: get });
  registerAnalytics(app, { verifyToken: deps.verifyToken, getDb: get, postHogFetch: deps.postHogFetch });
  registerBranding(app, { verifyToken: deps.verifyToken, getDb: get });

  return app;
}

const app = createApp();

export default {
  fetch: app.fetch,
  /** Daily cron: mark expired licenses (grace_end in the past). */
  async scheduled(_event: unknown, env: Env, ctx: unknown): Promise<void> {
    void _event;
    void ctx;
    const db = getDb(env);
    await db.sweepExpiredLicenses(Date.now());
  },
};
