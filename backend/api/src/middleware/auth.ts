/**
 * Auth middleware: verifies the Firebase ID token (Bearer), lazy-syncs the
 * user into Turso (Option B fallback for the in-app notify), and gates
 * admin-only routes by role.
 */
import type { Context, Next } from 'hono';
import { verifyFirebaseToken } from '../../../shared/src/jwt';
import type { TursoDb } from '../../../shared/src/turso';

/** Minimal env shape the Turso factory needs (rest of Env unused). */
export interface DbEnv {
  TURSO_DATABASE_URL: string;
  TURSO_AUTH_TOKEN: string;
}

export type VerifyTokenFn = (
  token: string,
  projectId: string,
) => Promise<{ valid: boolean; uid?: string; email?: string }>;

export function requireAuth(deps: {
  verifyToken?: VerifyTokenFn;
  db: (env: DbEnv) => TursoDb;
}) {
  const verifyToken = deps.verifyToken ?? verifyFirebaseToken;
  return async (
    c: Context<{
      Bindings: { TURSO_DATABASE_URL: string; TURSO_AUTH_TOKEN: string; FIREBASE_PROJECT_ID: string };
      Variables: { authUid: string; authEmail?: string };
    }>,
    next: Next,
  ) => {
    const authHeader = c.req.header('Authorization') ?? '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
    if (!token) return c.json({ ok: false, error: 'Missing bearer token' }, 401);

    const result = await verifyToken(token, c.env.FIREBASE_PROJECT_ID);
    if (!result.valid || !result.uid) {
      return c.json({ ok: false, error: 'Invalid token' }, 401);
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
