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
import { requireAuth, type VerifyTokenFn } from '../middleware/auth';
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
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
    sessionRepository: SessionRepository;
    authUserRepository: AuthUserRepository;
    userRepository: UserRepository;
    /** Optional injectable rate limiter for /sessions/start (login-style
     *  signature, T17). When absent the route falls back to a per-IP
     *  in-memory sliding window — a single-isolate budget, so a multi-deploy
     *  must inject a shared limiter for cross-isolate throttling (follow-up). */
    rateLimit?: (tenantId: string, username: string, ip: string, at: number) => Promise<{ allowed: boolean; retryAfterMs?: number }>;
  },
): void {
  const {
    sessionStart,
    sessionHeartbeat,
    sessionEnd,
    sessionListActive,
  } = deps;

  // Fallback limiter for /sessions/start: 30 starts/min/IP. State is bound to
  // this app instance (fresh per isolate/createApp), so tests get isolation
  // for free and production pays only one window per isolate.
  const SESSION_START_WINDOW_MS = 60_000;
  const SESSION_START_MAX_PER_WINDOW = 30;
  const SESSION_START_IP_MAP_SOFT_CAP = 10_000;
  const SESSION_START_IP_MAP_HARD_CAP = 5_000;
  const startHits = new Map<string, number[]>();
  const ipRateLimit = (ip: string, now: number): { allowed: boolean; retryAfterMs: number } => {
    const hits = (startHits.get(ip) ?? []).filter((t: number) => now - t < SESSION_START_WINDOW_MS);
    if (hits.length >= SESSION_START_MAX_PER_WINDOW) {
      const oldest = hits[0] ?? now;
      return { allowed: false, retryAfterMs: Math.max(0, oldest + SESSION_START_WINDOW_MS - now) };
    }
    hits.push(now);
    startHits.set(ip, hits);
    // Bounded memory: shed fully-expired IPs once the map grows too large.
    if (startHits.size > SESSION_START_IP_MAP_SOFT_CAP) {
      for (const [key, times] of startHits) {
        if (times.every((t: number) => now - t >= SESSION_START_WINDOW_MS)) startHits.delete(key);
        if (startHits.size <= SESSION_START_IP_MAP_HARD_CAP) break;
      }
    }
    return { allowed: true, retryAfterMs: 0 };
  };

  // Middleware gate for all session routes.
  app.use('/sessions/*', requireAuth({
    verifyToken: deps.verifyToken,
    sessionRepository: deps.sessionRepository,
    authUserRepository: deps.authUserRepository,
    userRepository: deps.userRepository,
  }));

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

    // Authenticated-abuse floor (review High #3): admission writes consume
    // device slots, so /sessions/start is throttled per client IP before the
    // use case runs. CF-Connecting-IP is the only trusted client-IP header
    // (Cloudflare sets it authoritatively); X-Forwarded-For is client-supplied
    // and spoofable, so it is intentionally NOT used for rate-limit keying.
    const injectable = deps.rateLimit
      ? await deps.rateLimit(c.get('authUid'), dto.username, c.req.header('CF-Connecting-IP')?.trim() ?? 'unknown', Date.now())
      : ipRateLimit(c.req.header('CF-Connecting-IP')?.trim() ?? 'unknown', Date.now());
    if (!injectable.allowed) {
      return c.json({ ok: false, error: 'RATE_LIMITED', retry_after_ms: injectable.retryAfterMs ?? 0 }, 429);
    }

    const result = await sessionStart.execute(dto);

    if (!result.ok) {
      switch (result.error) {
        case 'MISSING_FIELDS': return c.json({ ok: false, error: 'MISSING_FIELDS' }, 400);
        case 'USER_NOT_FOUND': return c.json({ ok: false, error: 'USER_NOT_FOUND' }, 401);
        case 'ACCOUNT_DISABLED': return c.json({ ok: false, error: 'ACCOUNT_DISABLED' }, 401);
        case 'NO_LICENSE': return c.json({ ok: false, error: 'NO_LICENSE' }, 401);
        case 'LICENSE_EXPIRED': return c.json({ ok: false, error: 'LICENSE_EXPIRED' }, 401);
        case 'DEVICE_LIMIT_EXCEEDED': return c.json({
          ok: false,
          error: 'DEVICE_LIMIT_EXCEEDED',
          active_sessions: result.activeSessions?.map((s) => ({
            id: s.sessionId,
            tenant_id: c.get('authUid'),
            device_hwid: s.deviceHwid ?? '',
            username: s.username,
            started_at: s.startedAt,
            heartbeat_at: s.heartbeatAt,
            ended_at: s.endedAt ?? null,
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
    // A non-owner caller always carries authUsername (the JWT `usr` claim).
    // An empty one means a malformed context — refuse instead of silently
    // skipping the ownership check (review Medium #9).
    if (!isOwner) {
      if (!callerUsername) return c.json({ ok: false, error: 'FORBIDDEN' }, 403);
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
    // Same hardening as /sessions/heartbeat (review Medium #9).
    if (!isOwner) {
      if (!callerUsername) return c.json({ ok: false, error: 'FORBIDDEN' }, 403);
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
    // Display endpoint cap (review Medium #11): a tenant with runaway sessions
    // must not stream an unbounded page. Revocation and the heartbeat/end
    // ownership lookups deliberately omit `limit` so they always see the full
    // live list.
    const dto: SessionListActiveDto = {
      tenantId: c.get('authUid'),
      limit: 50,
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
            device_hwid: s.deviceHwid ?? '',
            username: s.username,
            started_at: s.startedAt,
            heartbeat_at: s.heartbeatAt,
            ended_at: s.endedAt ?? null,
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
    const endResults = await Promise.allSettled(
      matching.map((session) => sessionEnd.execute({ sessionId: session.sessionId, tenantId })),
    );
    let ended = 0;
    for (const endResult of endResults) {
      if (endResult.status === 'fulfilled' && endResult.value.ok) ended++;
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
