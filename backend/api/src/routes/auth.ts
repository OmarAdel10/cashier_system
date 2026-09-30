/**
 * Auth routes:
 * - POST /auth/login        (public — registered BEFORE the /auth/* middleware)
 * - POST /auth/owner-refresh (Firebase owner only)
 * - POST /auth/sync-user     (Option A explicit sync after login)
 * - GET  /auth/me            (profile + license)
 * - POST /auth/logout        (session JWT bearer; ends own session)
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import { SESSION_FRESH_MS, type TursoDb } from '../../../shared/src/turso';
import { mintSessionJwt, verifySessionJwt } from '../../../shared/src/session_jwt';
import { verifyTagged } from '../../../shared/src/password_kdf';
import { checkLoginRateLimit } from '../../../shared/src/rate_limit';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireAuth, requireOwner } from '../middleware/auth';

/** Owner (Stage-1) re-auth window: forced Firebase re-login after 90 days. */
const OWNER_REAUTH_MS = 90 * 24 * 3600 * 1000;
/** A session with no heartbeat inside this window counts as stale/inactive.
 *  Aliased to the shared rule the auth gate enforces (turso.ts). */
const HEARTBEAT_FRESH_MS = SESSION_FRESH_MS;
/** Dashboard session JWT lifetime (seconds — JWT convention). */
const SESSION_TTL_S = 12 * 3600;

/** Exponential lockout from the 3rd failure; capped at 15 minutes.
 *  The helper persists; this formula (the policy) lives here, in the route. */
function lockUntilFor(failedAttempts: number): number | null {
  return failedAttempts >= 3
    ? Date.now() + Math.min(2 ** failedAttempts * 15_000, 900_000)
    : null;
}

/** T16 (DAFTARI-96): a real, valid-shaped tagged hash used as the derivation
 *  target when the username does not exist. It must parse and pass the
 *  44-char pre-check so verifyTagged pays the SAME PBKDF2 cost as a real row;
 *  the value itself is unreachable (a random salt is only ever hashed against
 *  it, and the compare is never trusted). 10,000 iterations keeps the Workers
 *  CPU budget identical to a real legacy-row verification. */
export const DUMMY_HASH =
  'pbkdf2-sha512$10000$c2FsdHNhbHQ$Eco9WRT2ISifrauSAE7fKpTReo4CJ3d88LINw4A6yeE=';

/** Trusted client IP for throttling (T17). Cloudflare always sets
 *  CF-Connecting-IP and strips a client-supplied copy, so it is the only
 *  unforgeable source in production; X-Forwarded-For is a dev/localhost
 *  fallback. 'unknown' is a deliberate shared bucket: requests that bypass
 *  both headers still share one (strict, never unlimited) window. */
function clientIp(c: { req: { header: (name: string) => string | undefined } }): string {
  const cf = c.req.header('CF-Connecting-IP')?.trim();
  if (cf) return cf;
  const xff = c.req.header('X-Forwarded-For')?.split(',')[0]?.trim();
  if (xff) return xff;
  return 'unknown';
}

export function registerAuth(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: {
    verifyToken?: VerifyTokenFn;
    getDb: (env: DbEnv) => TursoDb;
    verify?: typeof verifyTagged;
    rateLimit?: typeof checkLoginRateLimit;
  },
): void {
  const verify = deps.verify ?? verifyTagged;
  const rateLimit = deps.rateLimit ?? checkLoginRateLimit;
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

    // T17: throttle BEFORE the KDF and before touching auth_users. Either
    // dimension (IP or account) over budget → 429 with the exact wait. The
    // attempt is recorded only when admitted, so a rejected caller cannot
    // extend its own window.
    const ip = clientIp(c);
    const attemptAt = Date.now();
    const decision = await rateLimit(db, ip, tenantId, username, attemptAt);
    if (!decision.allowed) {
      return c.json(
        { ok: false, error: 'RATE_LIMITED', retry_after_ms: decision.retryAfterMs },
        429,
      );
    }
    await db.recordAuthAttempt(ip, tenantId, username, attemptAt);

    const user = await db.getAuthUser(tenantId, username);
    const now = Date.now();
    // T16: the KDF runs unconditionally — the derivation target is the real
    // stored hash when the account exists, otherwise a valid-shaped dummy.
    // Any early return that skipped it (unknown user, lockout, deactivated
    // account) would leak account existence through response timing.
    const derived = await verify(user?.password_hash ?? DUMMY_HASH, password);

    if (user && user.locked_until && user.locked_until > now) {
      return c.json({ ok: false, error: 'LOGIN_LOCKED', locked_until: user.locked_until }, 429);
    }
    // T16: an elapsed lock window restarts the counter. Without this reset the
    // stored failed_attempts (e.g. 30) carries into the next window and the
    // very next typo would re-lock immediately with the cap value.
    if (user && user.locked_until != null && user.locked_until <= now) {
      await db.resetAuthFailures(tenantId, username);
    }

    const passwordOk = user != null && user.is_active === 1 && derived;
    if (!passwordOk) {
      if (user) {
        // Counter is trustworthy here: a live lock returned above and an
        // expired one was just reset, so failed_attempts reflects this window.
        const attempts = user.locked_until != null && user.locked_until <= now
          ? 0
          : user.failed_attempts;
        await db.recordAuthFailure(tenantId, username, lockUntilFor(attempts + 1));
      }
      return c.json({ ok: false, error: 'BAD_CREDENTIALS' }, 401);
    }
    // Dashboard logins are admin-role only (cashier accounts are POS-side).
    if (user.role !== 'admin') {
      return c.json({ ok: false, error: 'DASHBOARD_ADMIN_ONLY' }, 403);
    }

    // 90-day owner re-auth gate (spec §1.3.2: expired > 3 months).
    //
    // T11 + security-review fix: this gate is UNCONDITIONAL on /auth/login.
    // It is deliberately NOT suppressed by the existence of an unended session
    // row. An earlier revision skipped it when
    // getActiveSessionsForUsername(tenantId, username, 0) returned anything,
    // but that predicate is `ended_at IS NULL AND heartbeat_at > ?` with
    // since = 0, i.e. 'any unended row ever' — and web rows survive until an
    // explicit logout or the next login. Treating one as proof of an active
    // session therefore let a single gated login suppress owner re-auth
    // FOREVER: a bypass, not the intended policy.
    //
    // The product requirement (the periodic owner re-auth must never interrupt
    // an ACTIVE admin session) is satisfied by /auth/session/resume below.
    // A resumed session is proven active by the /auth/* middleware — a valid
    // unexpired token AND a live session row — and that route never applies
    // this gate. A client holding an active session calls resume on reload,
    // never login; login is only reached once no session is live, which is
    // precisely when this gate is supposed to fire.
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
    // Web-session hygiene (T06 QA F1): end prior unended web rows for this
    // username so dashboard rows never accumulate (each login replaces the
    // last) and never linger in device-limit/admin views.
    await db.endWebSessions(tenantId, username, now);
    const sessionId = crypto.randomUUID();
    // Atomic single-web-session admission (T12): if another login raced us and
    // wrote a live web row for this (tenant, username) first, the partial
    // unique index rejects this insert and rowsAffected is 0. Refuse to mint a
    // token for a row that was never written.
    const admitted = await db.insertSession({
      id: sessionId,
      tenant_id: tenantId,
      device_hwid: 'web',
      username,
      started_at: now,
      heartbeat_at: now,
      source: 'web',
    });
    if (!admitted) {
      return c.json({ ok: false, error: 'SESSION_CONFLICT' }, 409);
    }
    const token = await mintSessionJwt(
      {
        tid: tenantId,
        usr: username,
        role: user.role,
        jti: sessionId,
        iat: Math.floor(now / 1000),
        exp: Math.floor(now / 1000) + SESSION_TTL_S,
      },
      c.env.ADMIN_JWT_SECRET,
    );
    return c.json({ ok: true, data: { token, session_id: sessionId, profile: owner } });
  });

  // Logout is registered BEFORE the /auth/* liveness middleware on purpose:
  // it must stay idempotent (a second call, with the row already ended, still
  // succeeds) and must be able to end a stale row. It verifies the same
  // session JWT inline and ignores the request body entirely, so the only
  // session it can end is the one named by the bearer token's `jti` — never
  // another session and never another tenant.
  app.post('/auth/logout', async (c) => {
    const authHeader = c.req.header('Authorization') ?? '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
    if (!token) return c.json({ ok: false, error: 'Missing bearer token' }, 401);
    const claims = await verifySessionJwt(token, c.env.ADMIN_JWT_SECRET);
    if (!claims) return c.json({ ok: false, error: 'Invalid session token' }, 401);
    await deps.getDb(c.env).endSessionForTenant(claims.jti, claims.tid, Date.now());
    return c.json({ ok: true });
  });

  app.use('/auth/*', requireAuth({ verifyToken: deps.verifyToken, db: deps.getDb }));

  app.post('/auth/owner-refresh', requireOwner(), async (c) => {
    const db = deps.getDb(c.env);
    await db.touchOwnerLogin(c.get('authUid'), Date.now());
    return c.json({ ok: true });
  });

  // Session resume (T11) — registered AFTER the /auth/* liveness middleware
  // above, which has already verified the bearer token AND that the session
  // row named by its `jti` still exists for this tenant and is unended.
  // Reaching this handler therefore proves an ACTIVE session, which is why the
  // 90-day owner gate is deliberately NOT re-applied here: it must never
  // interrupt an active admin session (it fires on /auth/login instead, i.e.
  // only once no session is live). This refreshes the SAME session row rather
  // than creating a new one, so device/session accounting is unchanged.
  app.post('/auth/session/resume', async (c) => {
    const db = deps.getDb(c.env);
    const tenantId = c.get('authUid');
    const sessionId = c.get('authSessionId');
    if (!sessionId) return c.json({ ok: false, error: 'SESSION_REVOKED' }, 401);
    const now = Date.now();
    const token = await mintSessionJwt(
      {
        tid: tenantId,
        usr: c.get('authUsername') ?? '',
        role: c.get('authRole') ?? 'admin',
        jti: sessionId,
        iat: Math.floor(now / 1000),
        exp: Math.floor(now / 1000) + SESSION_TTL_S,
      },
      c.env.ADMIN_JWT_SECRET,
    );
    const profile = await db.getUser(tenantId);
    return c.json({ ok: true, data: { token, session_id: sessionId, profile } });
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
