/**
 * Session routes: start (device-limit check), heartbeat, end, active list.
 * Device limits per tier: starter=1, pro=2, business=4.
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import type { TursoDb } from '../../../shared/src/turso';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireAuth } from '../middleware/auth';
import { TIER_DEVICE_LIMITS } from '../../../shared/src/types';

export function registerSessions(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: { verifyToken?: VerifyTokenFn; getDb: (env: DbEnv) => TursoDb },
): void {
  app.use('/sessions/*', requireAuth({ verifyToken: deps.verifyToken, db: deps.getDb }));

  app.post('/sessions/start', async (c) => {
    const uid = c.get('authUid');
    const db = deps.getDb(c.env);
    const body = await c.req.json<{
      device_hwid?: string;
      device_name?: string;
      platform?: string;
      username?: string;
    }>();
    const deviceHwid = body.device_hwid?.trim() ?? '';
    if (deviceHwid.length === 0) {
      return c.json({ ok: false, error: 'device_hwid is required' }, 400);
    }

    const user = await db.getUser(uid);
    const limit = TIER_DEVICE_LIMITS[user?.tier ?? 'starter'] ?? 1;
    const active = await db.getActiveSessions(uid);

    const reconnect = active.some((s) => s.device_hwid === deviceHwid);
    if (!reconnect && active.length >= limit) {
      return c.json(
        { ok: false, error: 'Device limit reached', active_sessions: active },
        409,
      );
    }

    const now = Date.now();
    await db.upsertDevice({
      tenant_id: uid,
      device_hwid: deviceHwid,
      device_name: body.device_name,
      platform: body.platform,
      first_seen_at: now,
      last_seen_at: now,
    });

    const sessionId = crypto.randomUUID();
    await db.insertSession({
      id: sessionId,
      tenant_id: uid,
      device_hwid: deviceHwid,
      username: body.username ?? '',
      started_at: now,
      heartbeat_at: now,
    });

    return c.json({ ok: true, data: { session_id: sessionId } });
  });

  app.post('/sessions/heartbeat', async (c) => {
    const db = deps.getDb(c.env);
    const body = await c.req.json<{ session_id?: string }>();
    if (!body.session_id) {
      return c.json({ ok: false, error: 'session_id is required' }, 400);
    }
    await db.heartbeatSession(body.session_id, Date.now());
    return c.json({ ok: true });
  });

  app.post('/sessions/end', async (c) => {
    const db = deps.getDb(c.env);
    const body = await c.req.json<{ session_id?: string }>();
    if (!body.session_id) {
      return c.json({ ok: false, error: 'session_id is required' }, 400);
    }
    await db.endSession(body.session_id, Date.now());
    return c.json({ ok: true });
  });

  app.get('/sessions/active', async (c) => {
    const db = deps.getDb(c.env);
    const sessions = await db.getActiveSessions(c.get('authUid'));
    return c.json({ ok: true, data: { sessions } });
  });
}
