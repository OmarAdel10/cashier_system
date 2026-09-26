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

/** Firebase sign-in methods allowed by the api (auth-licensing spec §2.1). */
export const ALLOWED_SIGNIN_PROVIDERS: readonly string[] = ['google.com', 'emailLink'];

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
      c.set('authUid', claims.tid);
      c.set('authUsername', claims.usr);
      c.set('authRole', claims.role);
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
