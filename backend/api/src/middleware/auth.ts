/**
 * Auth middleware: dual-token verification.
 *
 * - Firebase RS256 ID tokens (owner): verified against Google's JWKS,
 *   then gated by the sign-in provider allowlist (spec auth §2.1: only
 *   google.com and email link — password-provider tokens are rejected
 *   regardless of the console's forced Email/Password toggle) and the
 *   email_verified requirement. Lazy-syncs the user into Turso (Option B).
 * - Worker-minted HS256 session JWTs (dashboard admins): verified with
 *   ADMIN_JWT_SECRET (same secret as the realtime worker). Sets
 *   username/role vars; skips the lazy upsert (a session implies a prior
 *   login for an existing tenant).
 */
import type { Context, Next } from 'hono';
import { verifyFirebaseToken } from '../../../shared/src/jwt';
import { verifySessionJwt } from '../../../shared/src/session_jwt';
import type { TursoDb } from '../../../shared/src/turso';

/**
 * Firebase sign-in methods allowed by the api (auth-licensing spec §2.1).
 *
 * RESOLVED (plan T11, assumption 3): Firebase shares one provider id for the
 * Email/Password family, so an email-link (magic-link) sign-in carries
 * sign_in_provider 'password' — it is NOT distinguishable from a password
 * sign-in at the token layer, and Firebase requires the Email/Password
 * provider to be enabled for email links to work at all. Rejecting 'password'
 * therefore 401s every magic-link login as PROVIDER_NOT_ALLOWED, so
 * 'password' is allowed here and treated as the email-link path.
 *
 * Consequence to keep in mind: because the two are indistinguishable, this
 * allowlist can no longer be the control that prevents password sign-ups —
 * that is enforced in the Firebase console (Email/Password sign-up policy),
 * not here. Every Firebase token is still gated on email_verified below and
 * lazy-synced as its own tenant, which is the intended first-login bootstrap.
 */
export const ALLOWED_SIGNIN_PROVIDERS: readonly string[] = ['google.com', 'emailLink', 'password'];

/** Minimal env shape the Turso factory needs (rest of Env unused). */
export interface DbEnv {
  TURSO_DATABASE_URL: string;
  TURSO_AUTH_TOKEN: string;
}

export type VerifyTokenFn = (
  token: string,
  projectId: string,
) => Promise<{
  valid: boolean;
  uid?: string;
  email?: string;
  signInProvider?: string;
  emailVerified?: boolean;
}>;

/** Best-effort decode of the token header's alg field (no signature use). */
function decodeAlg(token: string): string | null {
  const part = token.split('.')[0];
  if (!part) return null;
  try {
    const normalized = part.replace(/-/g, '+').replace(/_/g, '/');
    const binary = atob(normalized + '='.repeat((4 - (normalized.length % 4)) % 4));
    return (JSON.parse(binary) as { alg?: string }).alg ?? null;
  } catch {
    return null;
  }
}

export function requireAuth(deps: {
  verifyToken?: VerifyTokenFn;
  db: (env: DbEnv) => TursoDb;
}) {
  const verifyToken = deps.verifyToken ?? verifyFirebaseToken;
  return async (
    c: Context<{
      Bindings: {
        TURSO_DATABASE_URL: string;
        TURSO_AUTH_TOKEN: string;
        FIREBASE_PROJECT_ID: string;
        ADMIN_JWT_SECRET: string;
      };
      Variables: {
        authUid: string;
        authEmail?: string;
        authUsername?: string;
        authRole?: string;
        authSessionId?: string;
        authIsOwner: boolean;
      };
    }>,
    next: Next,
  ) => {
    const authHeader = c.req.header('Authorization') ?? '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
    if (!token) return c.json({ ok: false, error: 'Missing bearer token' }, 401);

    // Worker-minted session JWT (HS256) — dashboard admins.
    if (decodeAlg(token) === 'HS256') {
      const claims = await verifySessionJwt(token, c.env.ADMIN_JWT_SECRET);
      if (!claims) return c.json({ ok: false, error: 'Invalid session token' }, 401);

      // Liveness gate (T10): a valid signature is not enough — the session
      // row named by `jti` must still belong to this tenant and be unended
      // (revocation == ended_at in this schema). Web sessions never heartbeat,
      // so there is no server-side staleness condition: a missing row and an
      // ended row are both SESSION_REVOKED. (SESSION_STALE is no longer emitted
      // server-side; the client keeps it in its Firebase re-auth routing list.)
      const db = deps.db(c.env);
      const live = await db.getLiveWebSession(claims.tid, claims.jti);
      if (!live) return c.json({ ok: false, error: 'SESSION_REVOKED' }, 401);

      // Account-status gate (security review): a live session row is not
      // enough. Deactivating an admin (users.ts sets is_active = 0) ends no
      // session row, and without this check a deactivated, downgraded or
      // renamed account kept full access AND could slide its 12h token forward
      // indefinitely by calling /auth/session/resume just before each expiry.
      // The account row is therefore re-read per request; when it is present
      // the CURRENT stored role wins over the role baked into the token, so a
      // downgrade takes effect immediately, and a deactivated row is refused.
      // A missing row is tolerated here (a session token can only have been
      // minted for an account that existed) — the tenant/username claim is
      // still scoped by the session row lookup above.
      const account = await db.getAuthUser(claims.tid, claims.usr);
      if (account && account.is_active !== 1) {
        return c.json({ ok: false, error: 'SESSION_REVOKED' }, 401);
      }

      c.set('authUid', claims.tid);
      c.set('authUsername', claims.usr);
      c.set('authRole', account?.role ?? claims.role);
      // The session row id is the token's `jti`; /auth/session/resume needs it
      // to mint a fresh token for the SAME row (T11).
      c.set('authSessionId', claims.jti);
      c.set('authIsOwner', false);
      await next();
      return;
    }

    // Firebase ID token (RS256) — the tenant owner.
    const result = await verifyToken(token, c.env.FIREBASE_PROJECT_ID);
    if (!result.valid || !result.uid) {
      return c.json({ ok: false, error: 'Invalid token' }, 401);
    }
    if (!ALLOWED_SIGNIN_PROVIDERS.includes(result.signInProvider ?? '')) {
      return c.json({ ok: false, error: 'PROVIDER_NOT_ALLOWED' }, 401);
    }
    if (result.emailVerified !== true) {
      return c.json({ ok: false, error: 'EMAIL_NOT_VERIFIED' }, 401);
    }

    const db = deps.db(c.env);
    // Lazy sync (Option B): ensure the user row exists.
    const existing = await db.getUser(result.uid);
    if (!existing) {
      await db.upsertUser({
        tenant_id: result.uid,
        email: result.email ?? '',
        role: 'admin',
        created_at: Date.now(),
      });
    }

    c.set('authUid', result.uid);
    if (result.email) c.set('authEmail', result.email);
    c.set('authIsOwner', true);
    await next();
  };
}

/** Owner-only gate: Firebase (Stage-1) tokens pass; session admins 403. */
export function requireOwner() {
  return async (c: Context<{ Variables: { authIsOwner: boolean } }>, next: Next) => {
    if (c.get('authIsOwner') !== true) {
      return c.json({ ok: false, error: 'OWNER_ONLY' }, 403);
    }
    await next();
  };
}

export function requireAdmin(deps: {
  db: (env: { TURSO_DATABASE_URL: string; TURSO_AUTH_TOKEN: string }) => TursoDb;
}) {
  return async (
    c: Context<{
      Bindings: { TURSO_DATABASE_URL: string; TURSO_AUTH_TOKEN: string };
      Variables: { authUid: string };
    }>,
    next: Next,
  ) => {
    const db = deps.db(c.env);
    const user = await db.getUser(c.get('authUid'));
    if (!user || user.role !== 'admin') {
      return c.json({ ok: false, error: 'Admin access only' }, 403);
    }
    await next();
  };
}
