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
import { verifyFirebaseToken } from 'daftari-backend-shared/jwt';
import { registerSales } from './routes/sales';
import { registerAdmin } from './routes/admin';
import { registerUsers } from './routes/users';
import { registerAnalytics } from './routes/analytics';
import { registerBranding } from './routes/branding';
import { registerAuth } from './routes/auth';
import { registerSessions } from './routes/sessions';
import { createApiRuntime } from './runtime';
import type { ApiRuntimeEnv } from './application/ports';
import type { FirebaseTokenVerifier } from './application/ports';
import type { FetchFn } from '../../shared/src/types';
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

export interface ApiDeps {
  verifyToken?: FirebaseTokenVerifier;
  getDb?: typeof getDb;
  postHogFetch?: FetchFn;
  /** Injectable KDF verifier (T16): lets a test assert the derivation runs
   *  even for an unknown username. Defaults to the real verifyTagged. */
  verify?: typeof verifyTagged;
  /** Injectable login rate limiter (T17): default is the real sliding window. */
  rateLimit?: (tenantId: string, username: string, ip: string, at: number) => Promise<{ allowed: boolean; retryAfterMs?: number }>;
  /** Shared admin JWT secret used for signing session JWTs. Required — no fallback. */
  adminJwtSecret: string;
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

export function createApp(deps: ApiDeps) {
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

  // Global error handler: maps SyntaxError (malformed JSON) → 400 INVALID_JSON,
  // everything else → 500 INTERNAL (no stack in body).
  app.onError((err, c) => {
    if (err instanceof SyntaxError) {
      return c.json({ ok: false, error: 'INVALID_JSON' }, 400);
    }
    return c.json({ ok: false, error: 'INTERNAL' }, 500);
  });

  app.get('/health', async (c) => {
    const db = get(c.env);
    const schema = await db.checkSchema();
    const schemaOk = schema.authUsers && schema.sessionsSource;
    return c.json({
      ok: schemaOk,
      env: c.env.ENVIRONMENT ?? 'unknown',
      db: schemaOk ? 'ok' : 'unreachable',
      schema: {
        auth_users: schema.authUsers,
        sessions_source: schema.sessionsSource,
        users_last_owner_login_at: schema.usersLastOwnerLoginAt,
      },
      secrets: {
        admin_jwt_secret: !!c.env.ADMIN_JWT_SECRET,
      },
    }, schemaOk ? 200 : 503);
  });

  const runtime = createApiRuntime({
    getDb,
    verifyToken: deps.verifyToken ?? verifyFirebaseToken,
  });
  const dummyEnv: ApiRuntimeEnv = {
    TURSO_DATABASE_URL: 'https://dummy.turso.io',
    TURSO_AUTH_TOKEN: 'dummy-token',
    ADMIN_JWT_SECRET: deps.adminJwtSecret,
    FIREBASE_PROJECT_ID: 'dummy-project',
    POSTHOG_API_KEY: 'phc_test',
    verifyToken: deps.verifyToken ?? verifyFirebaseToken,
    verify: deps.verify ?? verifyTagged,
  };
  const services = runtime.getServices(dummyEnv);
  const useCases = {
    dashboardLogin: new DashboardLoginUseCase(
      services.auth.authUserRepository,
      services.auth.sessionRepository,
      services.auth.licenseRepository,
      services.auth.userRepository,
      services.auth.authService,
      services.auth.rateLimiter,
      services.auth.sessionTokenService,
      deps.adminJwtSecret,
      deps.verify ?? verifyTagged,
    ),
    dashboardLogout: new DashboardLogoutUseCase(services.auth.sessionRepository),
    ownerRefresh: new OwnerRefreshUseCase(services.auth.userRepository),
    sessionResume: new AuthSessionResumeUseCase(
      services.auth.sessionTokenService,
      services.auth.userRepository,
      deps.adminJwtSecret,
    ),
    getAuthProfile: new GetAuthProfileUseCase(
      services.auth.userRepository,
      services.auth.licenseRepository,
    ),
    syncFirebaseUser: new SyncFirebaseUserUseCase(
      services.auth.userRepository,
      services.auth.licenseRepository,
    ),
    issueRealtimeTicket: new IssueRealtimeTicketUseCase(
      services.auth.userRepository,
      services.auth.realtimeTicketRepository,
    ),
    validateRealtimeTicket: new ValidateRealtimeTicketUseCase(
      services.auth.realtimeTicketRepository,
    ),
    sessionStart: new SessionStartUseCase(
      services.auth.sessionRepository,
      services.auth.deviceRepository,
      services.auth.licenseRepository,
      services.auth.authUserRepository,
      services.auth.userRepository,
      services.auth.sessionTokenService,
      deps.adminJwtSecret,
    ),
    sessionHeartbeat: new SessionHeartbeatUseCase(services.auth.sessionRepository),
    sessionEnd: new SessionEndUseCase(services.auth.sessionRepository),
    sessionListActive: new SessionListActiveUseCase(services.auth.sessionRepository),
  };
  registerAuth(app, {
    useCases,
    getDb: get,
    verifyToken: deps.verifyToken ?? verifyFirebaseToken,
    verify: deps.verify ?? verifyTagged,
    rateLimit: deps.rateLimit,
  });
  registerSessions(app, {
    sessionStart: useCases.sessionStart,
    sessionHeartbeat: useCases.sessionHeartbeat,
    sessionEnd: useCases.sessionEnd,
    sessionListActive: useCases.sessionListActive,
    verifyToken: deps.verifyToken,
    getDb: get,
    rateLimit: deps.rateLimit,
  });
  registerSales(app, { verifyToken: deps.verifyToken, getDb: get });
  registerAdmin(app, { verifyToken: deps.verifyToken, getDb: get });
  // After registerAdmin: the /admin/* requireAuth middleware covers these.
  registerUsers(app, { verifyToken: deps.verifyToken, getDb: get });
  registerAnalytics(app, { verifyToken: deps.verifyToken, getDb: get, postHogFetch: deps.postHogFetch });
  registerBranding(app, { verifyToken: deps.verifyToken, getDb: get });

  return app;
}

let app: Hono<{ Bindings: Env; Variables: Vars }>;
// ADMIN_JWT_SECRET is the only module-load prerequisite (it gates the runtime
// credential check inside createApp). When absent the deployment is invalid:
// serve a clean 503 instead of crashing the worker. Any OTHER error from
// createApp is a real bug and must propagate loudly — masking every failure
// as 503 hides coding errors behind an 'API not configured' response.
const moduleAdminJwtSecret = process.env.ADMIN_JWT_SECRET ?? '';
if (moduleAdminJwtSecret) {
  app = createApp({ adminJwtSecret: moduleAdminJwtSecret });
} else {
  app = new Hono<{ Bindings: Env; Variables: Vars }>();
  app.all('*', (c) => c.json({ ok: false, error: 'API not configured' }, 503));
}

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
