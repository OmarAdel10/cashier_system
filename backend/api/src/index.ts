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

export interface ApiDeps {
  verifyToken?: VerifyTokenFn;
  getDb?: typeof getDb;
  postHogFetch?: FetchFn;
}

export function createApp(deps: ApiDeps = {}) {
  const get = deps.getDb ?? getDb;
  const app = new Hono<{ Bindings: Env; Variables: Vars }>();

  app.use('*', cors());

  app.get('/health', (c) => c.json({ ok: true, env: c.env.ENVIRONMENT ?? 'unknown' }));

  registerAuth(app, { verifyToken: deps.verifyToken, getDb: get });
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
