/**
 * Session routes: start (device-limit check), heartbeat, end, active list.
 * Device limits per tier: starter=1, pro=2, business=4.
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import type { TursoDb } from '../../../shared/src/turso';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireAuth } from '../middleware/auth';
import { notifyRealtime } from '../realtime';
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

    const now = Date.now();
    const sessionId = crypto.randomUUID();
    // Atomic admission (T12): the slot check and the insert are one statement,
    // so two concurrent starts cannot both take the last free slot. A false
    // result is the authoritative rejection (not a pre-count race).
    const admitted = await db.admitPosSession(
      {
        id: sessionId,
        tenant_id: uid,
        device_hwid: deviceHwid,
        username: body.username ?? '',
        started_at: now,
        heartbeat_at: now,
        source: 'pos',
      },
      limit,
    );
    if (!admitted) {
      const active = await db.getActivePosSessions(uid);
      return c.json(
        { ok: false, error: 'Device limit reached', active_sessions: active },
        409,
      );
    }

    await db.upsertDevice({
      tenant_id: uid,
      device_hwid: deviceHwid,
      device_name: body.device_name,
      platform: body.platform,
      first_seen_at: now,
      last_seen_at: now,
    });

    return c.json({ ok: true, data: { session_id: sessionId } });
  });

  app.post('/sessions/heartbeat', async (c) => {
    const db = deps.getDb(c.env);
    const body = await c.req.json<{ session_id?: string }>();
    if (!body.session_id) {
      return c.json({ ok: false, error: 'session_id is required' }, 400);
    }
    // T13 IDOR: the tenant comes from the verified token, so a foreign or
    // unknown session id matches no row and is reported as 404.
    const ok = await db.heartbeatSession(body.session_id, c.get('authUid'), Date.now());
    if (!ok) return c.json({ ok: false, error: 'SESSION_NOT_FOUND' }, 404);
    return c.json({ ok: true });
  });

  app.post('/sessions/end', async (c) => {
    const db = deps.getDb(c.env);
    const body = await c.req.json<{ session_id?: string }>();
    if (!body.session_id) {
      return c.json({ ok: false, error: 'session_id is required' }, 400);
    }
    const ok = await db.endSession(body.session_id, c.get('authUid'), Date.now());
    if (!ok) return c.json({ ok: false, error: 'SESSION_NOT_FOUND' }, 404);
    return c.json({ ok: true });
  });

  app.get('/sessions/active', async (c) => {
    const db = deps.getDb(c.env);
    const sessions = await db.getActiveSessions(c.get('authUid'));
    return c.json({ ok: true, data: { sessions } });
  });

  /** Ends the username's active sessions (session-conflict UX, spec §6.5)
   *  and notifies the realtime worker so dashboards refresh. Auth'd: the
   *  tenant is taken from the token, so this can only touch own-tenant
   *  sessions. */
  app.post('/sessions/revoke', async (c) => {
    const db = deps.getDb(c.env);
    const body = await c.req.json<{ username?: string }>();
    const username = body.username?.trim() ?? '';
    if (!username) return c.json({ ok: false, error: 'MISSING_FIELDS' }, 400);

    const tenantId = c.get('authUid');
    const now = Date.now();
    const active = await db.getActiveSessionsForUsername(
      tenantId,
      username,
      now - 5 * 60 * 1000,
    );
    for (const session of active) {
      await db.endSession(session.id, tenantId, now);
    }

    const realtime = c.env.REALTIME;
    if (realtime && active.length > 0) {
      const notifyPromise = notifyRealtime(c.env, tenantId, 'session_revoked', {
        username,
        at: now,
      });
      // In Workers, executionCtx.waitUntil extends lifetime. In tests the
      // getter throws, so wrap it.
      try {
        c.executionCtx.waitUntil(notifyPromise);
      } catch {
        await notifyPromise;
      }
    }
    return c.json({ ok: true, data: { ended: active.length } });
  });
}
