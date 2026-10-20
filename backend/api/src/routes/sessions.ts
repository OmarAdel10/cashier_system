/**
 * Session routes: start (device-limit check), heartbeat, end, active list.
 * Device limits per tier: starter=1, pro=2, business=4.
 *
 * All business logic lives in application-layer use cases. Routes handle only
 * HTTP parsing, validation, delegation, and response formatting.
 *
 * Wiring precondition: identity fields (tenantId/sessionId/username) must be
 * sourced ONLY from verified middleware context (c.get('authUid') etc.),
 * never from request body/query/header. Authz (requireAuth) is enforced by
 * middleware before these handlers run.
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import { requireAuth, type DbEnv, type VerifyTokenFn } from '../middleware/auth';
import { notifyRealtime } from '../realtime';
import {
  SessionStartUseCase,
} from '../application/use-cases/session-start-use-case';
import {
  SessionHeartbeatUseCase,
} from '../application/use-cases/session-heartbeat-use-case';
import {
  SessionEndUseCase,
} from '../application/use-cases/session-end-use-case';
import {
  SessionListActiveUseCase,
} from '../application/use-cases/session-list-active-use-case';
import type { SessionStartDto } from '../application/dtos/session-start.dto';
import type { SessionHeartbeatDto } from '../application/dtos/session-heartbeat.dto';
import type { SessionEndDto } from '../application/dtos/session-end.dto';
import type { SessionListActiveDto } from '../application/dtos/session-list-active.dto';

export function registerSessions(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: {
    sessionStart: SessionStartUseCase;
    sessionHeartbeat: SessionHeartbeatUseCase;
    sessionEnd: SessionEndUseCase;
    sessionListActive: SessionListActiveUseCase;
    verifyToken?: VerifyTokenFn;
    getDb: (env: DbEnv) => import('daftari-backend-shared/turso').TursoDb;
  },
): void {
  const {
    sessionStart,
    sessionHeartbeat,
    sessionEnd,
    sessionListActive,
  } = deps;

  // Middleware gate for all session routes.
  app.use('/sessions/*', requireAuth({ verifyToken: deps.verifyToken, db: deps.getDb }));

  app.post('/sessions/start', async (c) => {
    const body = await c.req.json<{
      device_hwid?: string;
      device_name?: string;
      platform?: string;
      username?: string;
      source?: 'pos' | 'web';
    }>();
    const deviceHwid = body.device_hwid?.trim() ?? '';
    if (deviceHwid.length === 0) {
      return c.json({ ok: false, error: 'device_hwid is required' }, 400);
    }

    const dto: SessionStartDto = {
      tenantId: c.get('authUid'),
      deviceHwid,
      username: c.get('authUsername') ?? '',
      source: body.source ?? 'pos',
    };

    if (!dto.username) {
      return c.json({ ok: false, error: 'MISSING_FIELDS' }, 400);
    }

    const result = await sessionStart.execute(dto);

    if (!result.ok) {
      switch (result.error) {
        case 'MISSING_FIELDS': return c.json({ ok: false, error: 'MISSING_FIELDS' }, 400);
        case 'USER_NOT_FOUND': return c.json({ ok: false, error: 'USER_NOT_FOUND' }, 401);
        case 'ACCOUNT_DISABLED': return c.json({ ok: false, error: 'ACCOUNT_DISABLED' }, 401);
        case 'NO_LICENSE': return c.json({ ok: false, error: 'NO_LICENSE' }, 401);
        case 'LICENSE_EXPIRED': return c.json({ ok: false, error: 'LICENSE_EXPIRED' }, 401);
        case 'SESSION_CONFLICT': return c.json({ ok: false, error: 'SESSION_CONFLICT' }, 409);
        case 'DEVICE_LIMIT_EXCEEDED': return c.json({
          ok: false,
          error: 'DEVICE_LIMIT_EXCEEDED',
          active_sessions: result.activeSessions?.map((s) => ({
            id: s.sessionId,
            tenant_id: c.get('authUid'),
            device_hwid: '',
            username: s.username,
            started_at: s.startedAt,
            heartbeat_at: s.heartbeatAt,
            ended_at: null,
            source: s.source,
          })) ?? [],
        }, 409);
        case 'SESSION_CREATION_FAILED': return c.json({ ok: false, error: 'SESSION_CREATION_FAILED' }, 500);
        default: return c.json({ ok: false, error: 'INTERNAL_ERROR' }, 500);
      }
    }

    return c.json({ ok: true, data: { session_id: result.data.sessionId } });
  });

  app.post('/sessions/heartbeat', async (c) => {
    const body = await c.req.json<{ session_id?: string }>();
    if (!body.session_id) {
      return c.json({ ok: false, error: 'session_id is required' }, 400);
    }
    const callerUsername = c.get('authUsername') ?? '';
    const isOwner = c.get('authIsOwner') === true;
    if (!isOwner && callerUsername) {
      const listResult = await sessionListActive.execute({ tenantId: c.get('authUid') });
      const session = listResult.data.sessions.find((s) => s.sessionId === body.session_id);
      if (!session || session.username !== callerUsername) {
        return c.json({ ok: false, error: 'SESSION_NOT_FOUND' }, 404);
      }
    }

    const dto: SessionHeartbeatDto = {
      sessionId: body.session_id,
      tenantId: c.get('authUid'),
    };

    const result = await sessionHeartbeat.execute(dto);
    if (!result.ok) return c.json({ ok: false, error: 'SESSION_NOT_FOUND' }, 404);
    return c.json({ ok: true });
  });

  app.post('/sessions/end', async (c) => {
    const body = await c.req.json<{ session_id?: string }>();
    if (!body.session_id) {
      return c.json({ ok: false, error: 'session_id is required' }, 400);
    }
    const callerUsername = c.get('authUsername') ?? '';
    const isOwner = c.get('authIsOwner') === true;
    if (!isOwner && callerUsername) {
      const listResult = await sessionListActive.execute({ tenantId: c.get('authUid') });
      const session = listResult.data.sessions.find((s) => s.sessionId === body.session_id);
      if (!session || session.username !== callerUsername) {
        return c.json({ ok: false, error: 'SESSION_NOT_FOUND' }, 404);
      }
    }

    const dto: SessionEndDto = {
      sessionId: body.session_id,
      tenantId: c.get('authUid'),
    };

    const result = await sessionEnd.execute(dto);
    if (!result.ok) return c.json({ ok: false, error: 'SESSION_NOT_FOUND' }, 404);
    return c.json({ ok: true });
  });

  app.get('/sessions/active', async (c) => {
    const dto: SessionListActiveDto = {
      tenantId: c.get('authUid'),
    };

    const result = await sessionListActive.execute(dto);
    const isOwner = c.get('authIsOwner') === true;
    const callerUsername = c.get('authUsername') ?? '';
    return c.json({
      ok: true,
      data: {
        sessions: result.data.sessions
          .filter((s) => isOwner || s.username === callerUsername)
          .map((s) => ({
            id: s.sessionId,
            tenant_id: c.get('authUid'),
            device_hwid: '',
            username: s.username,
            started_at: s.startedAt,
            heartbeat_at: s.heartbeatAt,
            ended_at: null,
            source: s.source,
          })),
      },
    });
  });

  /** Ends the username's active sessions (session-conflict UX, spec §6.5)
   *  and notifies the realtime worker so dashboards refresh. Auth'd: the
   *  tenant is taken from the token, so this can only touch own-tenant
   *  sessions. DB mutation is delegated to SessionListActiveUseCase +
   *  SessionEndUseCase; the route owns filtering by username and the
   *  realtime notification (presentation concerns only). */
  app.post('/sessions/revoke', async (c) => {
    const body = await c.req.json<{ username?: string }>();
    const username = body.username?.trim() ?? '';
    if (!username) return c.json({ ok: false, error: 'MISSING_FIELDS' }, 400);

    // T14: tenant scoping alone lets any session admin in the tenant revoke
    // ANY username, including another admin's live sessions (a takeover /
    // denial-of-service weapon). A session-token caller may only revoke its
    // own username; the Firebase owner may revoke any username in the tenant.
    // ADMIN inside the same tenant is NOT enough — revocation is not a
    // peer-admin privilege. Checked before any DB read or endSession write.
    const callerUsername = c.get('authUsername') ?? '';
    if (c.get('authIsOwner') !== true && callerUsername !== username) {
      return c.json({ ok: false, error: 'FORBIDDEN' }, 403);
    }

    const tenantId = c.get('authUid');
    const now = Date.now();

    // List active sessions for the tenant, filter by username, end each via use case.
    const listResult = await sessionListActive.execute({ tenantId });
    const matching = listResult.data.sessions.filter((s) => s.username === username);
    let ended = 0;
    for (const session of matching) {
      const endResult = await sessionEnd.execute({ sessionId: session.sessionId, tenantId });
      if (endResult.ok) ended++;
    }

    const realtime = c.env.REALTIME;
    if (realtime && ended > 0) {
      const notifyPromise = notifyRealtime(c.env, tenantId, 'session_revoked', {
        username,
        at: now,
      });
      try {
        c.executionCtx.waitUntil(notifyPromise);
      } catch {
        await notifyPromise;
      }
    }
    return c.json({ ok: true, data: { ended } });
  });
}
