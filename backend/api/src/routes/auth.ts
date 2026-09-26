/**
 * Auth routes:
 * - POST /auth/login        (public — registered BEFORE the /auth/* middleware)
 * - POST /auth/owner-refresh (Firebase owner only)
 * - POST /auth/sync-user     (Option A explicit sync after login)
 * - GET  /auth/me            (profile + license)
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import type { TursoDb } from '../../../shared/src/turso';
import { mintSessionJwt } from '../../../shared/src/session_jwt';
import { verifyTagged } from '../../../shared/src/password_kdf';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireAuth, requireOwner } from '../middleware/auth';

/** Owner (Stage-1) re-auth window: forced Firebase re-login after 90 days. */
const OWNER_REAUTH_MS = 90 * 24 * 3600 * 1000;
/** A session with no heartbeat inside this window counts as stale/inactive. */
const HEARTBEAT_FRESH_MS = 5 * 60 * 1000;
/** Dashboard session JWT lifetime (seconds — JWT convention). */
const SESSION_TTL_S = 12 * 3600;

/** Exponential lockout from the 3rd failure; capped at 15 minutes.
 *  The helper persists; this formula (the policy) lives here, in the route. */
function lockUntilFor(failedAttempts: number): number | null {
  return failedAttempts >= 3
    ? Date.now() + Math.min(2 ** failedAttempts * 15_000, 900_000)
    : null;
}

export function registerAuth(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: { verifyToken?: VerifyTokenFn; getDb: (env: DbEnv) => TursoDb },
): void {
  // Public login — MUST be registered before the /auth/* middleware below
  // (Hono applies middleware in registration order; the route first = no
  // auth required on it).
  app.post('/auth/login', async (c) => {
    const db = deps.getDb(c.env);
    const body = await c.req.json<{ tenant_id?: string; username?: string; password?: string }>();
    const tenantId = body.tenant_id?.trim() ?? '';
    const username = body.username?.trim() ?? '';
    const password = body.password ?? '';
    if (!tenantId || !username || !password) {
      return c.json({ ok: false, error: 'MISSING_FIELDS' }, 400);
    }

    const user = await db.getAuthUser(tenantId, username);
    if (user && user.locked_until && user.locked_until > Date.now()) {
      return c.json({ ok: false, error: 'LOGIN_LOCKED', locked_until: user.locked_until }, 429);
    }
    const passwordOk =
      user != null && user.is_active === 1 && (await verifyTagged(user.password_hash, password));
    if (!passwordOk) {
      if (user) {
        await db.recordAuthFailure(tenantId, username, lockUntilFor(user.failed_attempts + 1));
      }
      return c.json({ ok: false, error: 'BAD_CREDENTIALS' }, 401);
    }
    // Dashboard logins are admin-role only (cashier accounts are POS-side).
    if (user.role !== 'admin') {
      return c.json({ ok: false, error: 'DASHBOARD_ADMIN_ONLY' }, 403);
    }

    // 90-day owner re-auth gate (spec §1.3.2: expired > 3 months).
    const owner = await db.getUser(tenantId);
    const ownerFresh =
      owner?.last_owner_login_at != null &&
      Date.now() - owner.last_owner_login_at <= OWNER_REAUTH_MS;
    if (!ownerFresh) {
      return c.json({ ok: false, error: 'OWNER_REAUTH_REQUIRED' }, 401);
    }

    // Per-username single-session conflict core (spec §6.5). Stale
    // heartbeats (> 5 min) do not block login.
    const active = await db.getActiveSessionsForUsername(
      tenantId,
      username,
      Date.now() - HEARTBEAT_FRESH_MS,
    );
    if (active.length > 0) {
      return c.json(
        { ok: false, error: 'SESSION_CONFLICT', conflict_session_id: active[0]!.id },
        409,
      );
    }

    await db.resetAuthFailures(tenantId, username);
    const now = Date.now();
    // Web-session hygiene (T06 QA F1): end prior unended web rows for this
    // username so dashboard rows never accumulate (each login replaces the
    // last) and never linger in device-limit/admin views.
    await db.endWebSessions(tenantId, username, now);
    const sessionId = crypto.randomUUID();
    await db.insertSession({
      id: sessionId,
      tenant_id: tenantId,
      device_hwid: 'web',
      username,
      started_at: now,
      heartbeat_at: now,
      source: 'web',
    });
    const token = await mintSessionJwt(
      {
        tid: tenantId,
        usr: username,
        role: user.role,
        iat: Math.floor(now / 1000),
        exp: Math.floor(now / 1000) + SESSION_TTL_S,
      },
      c.env.ADMIN_JWT_SECRET,
    );
    return c.json({ ok: true, data: { token, session_id: sessionId, profile: owner } });
  });

  app.use('/auth/*', requireAuth({ verifyToken: deps.verifyToken, db: deps.getDb }));

  app.post('/auth/owner-refresh', requireOwner(), async (c) => {
    const db = deps.getDb(c.env);
    await db.touchOwnerLogin(c.get('authUid'), Date.now());
    return c.json({ ok: true });
  });

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
