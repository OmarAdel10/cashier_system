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

  /** Devices view for the dashboard: device cards + the active POS session
   *  per device. Web session rows (device_hwid 'web') have no devices row,
   *  so they never appear here (T06 QA F1 note). */
  app.get('/admin/devices', requireAdmin({ db: deps.getDb }), async (c) => {
    const db = deps.getDb(c.env);
    const uid = c.get('authUid');
    const devices = await db.listDevices(uid);
    const active = await db.getActiveSessions(uid);
    const byHwid = new Map(active.map((s) => [s.device_hwid, s]));
    return c.json({
      ok: true,
      data: {
        devices: devices.map((d) => {
          const session = byHwid.get(d.device_hwid);
          return {
            ...d,
            active_session: session
              ? { id: session.id, username: session.username, started_at: session.started_at }
              : undefined,
          };
        }),
      },
    });
  });

  /** Recent activity feed: latest sales + sessions merged, newest first. */
  app.get('/admin/activity', requireAdmin({ db: deps.getDb }), async (c) => {
    const db = deps.getDb(c.env);
    const uid = c.get('authUid');
    const [sales, sessions] = await Promise.all([
      db.listSales(uid, 0),
      db.getRecentSessions(uid, 5),
    ]);
    const events = [
      ...sales.slice(-5).map((s) => ({
        type: 'sale' as const,
        at: s.created_at,
        summary: `${s.total_piastres} piastres`,
      })),
      ...sessions.map((s) => ({
        type: 'session' as const,
        at: s.started_at,
        summary: `${s.username} on ${s.device_hwid}`,
      })),
    ]
      .sort((a, b) => b.at - a.at)
      .slice(0, 10);
    return c.json({ ok: true, data: { events } });
  });
}
