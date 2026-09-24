/**
 * Auth routes: POST /auth/sync-user (Option A explicit sync after login)
 * and GET /auth/me (profile + license).
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import type { TursoDb } from '../../../shared/src/turso';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireAuth } from '../middleware/auth';

export function registerAuth(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: { verifyToken?: VerifyTokenFn; getDb: (env: DbEnv) => TursoDb },
): void {
  app.use('/auth/*', requireAuth({ verifyToken: deps.verifyToken, db: deps.getDb }));

  app.post('/auth/sync-user', async (c) => {
    const uid = c.get('authUid');
    const email = c.get('authEmail');
    const db = deps.getDb(c.env);
    // Middleware lazy-sync already ran; prefer a real row, fall back to the
    // just-created profile (Option A: immediate response after first sync).
    const profile =
      (await db.getUser(uid)) ?? {
        tenant_id: uid,
        email: email ?? '',
        role: 'admin',
        created_at: Date.now(),
      };
    const license = await db.getLatestLicense(uid);
    return c.json({ ok: true, data: { profile, license } });
  });

  app.get('/auth/me', async (c) => {
    const uid = c.get('authUid');
    const db = deps.getDb(c.env);
    const profile = await db.getUser(uid);
    const license = await db.getLatestLicense(uid);
    return c.json({ ok: true, data: { profile, license } });
  });
}
