/**
 * Admin routes: read-only overview for the web admin dashboard.
 * Requires role='admin' (cashiers or unknown users → 403).
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import type { TursoDb } from '../../../shared/src/turso';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireAdmin, requireAuth } from '../middleware/auth';

export function registerAdmin(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: { verifyToken?: VerifyTokenFn; getDb: (env: DbEnv) => TursoDb },
): void {
  app.use('/admin/*', requireAuth({ verifyToken: deps.verifyToken, db: deps.getDb }));

  app.get('/admin/overview', requireAdmin({ db: deps.getDb }), async (c) => {
    const uid = c.get('authUid');
    const db = deps.getDb(c.env);
    const stats = await db.getTenantStats(uid);
    const sessions = await db.getActiveSessions(uid);
    return c.json({
      ok: true,
      data: {
        tenant_id: uid,
        stats,
        active_sessions: sessions.length,
      },
    });
  });
}
