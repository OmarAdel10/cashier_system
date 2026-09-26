/**
 * Users CRUD for the dashboard Users Management section (T07).
 *
 * GET/POST: any authenticated admin (owner or session). Creating
 * admin-role accounts is owner-only (spec §2.4: only the Firebase
 * owner creates/modifies admins; any admin creates cashiers).
 * PATCH/DELETE: owner-only.
 *
 * NOTE: the /admin/* requireAuth middleware is registered by
 * registerAdmin() BEFORE this module — all routes here are protected.
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import type { AuthUserRecord } from '../../../shared/src/types';
import type { TursoDb } from '../../../shared/src/turso';
import { hashTagged } from '../../../shared/src/password_kdf';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireOwner } from '../middleware/auth';

const USERNAME_RE = /^[a-zA-Z0-9_]{3,30}$/;
const MIN_PASSWORD = 8;

/** Wire shape: never expose password_hash or lockout bookkeeping. */
function toWireUser(u: AuthUserRecord) {
  return {
    tenant_id: u.tenant_id,
    username: u.username,
    role: u.role,
    display_name: u.display_name,
    must_change_password: u.must_change_password,
    is_active: u.is_active,
    created_at: u.created_at,
    updated_at: u.updated_at,
  };
}

export function registerUsers(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: { verifyToken?: VerifyTokenFn; getDb: (env: DbEnv) => TursoDb },
): void {
  app.get('/admin/users', async (c) => {
    const db = deps.getDb(c.env);
    const users = await db.listAuthUsers(c.get('authUid'));
    return c.json({ ok: true, data: { users: users.map(toWireUser) } });
  });

  app.post('/admin/users', async (c) => {
    const db = deps.getDb(c.env);
    const body = await c.req.json<{
      username?: string;
      password?: string;
      role?: string;
      display_name?: string;
    }>();
    const username = body.username?.trim() ?? '';
    const password = body.password ?? '';
    const role = body.role ?? '';
    const displayName = body.display_name?.trim() || undefined;
    if (
      !USERNAME_RE.test(username) ||
      password.length < MIN_PASSWORD ||
      (role !== 'admin' && role !== 'cashier')
    ) {
      return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
    }
    // Owner-only admin management (spec §2.4): session admins may only
    // create cashiers.
    if (role === 'admin' && c.get('authIsOwner') !== true) {
      return c.json({ ok: false, error: 'ADMIN_MANAGEMENT_OWNER_ONLY' }, 403);
    }
    const existing = await db.getAuthUser(c.get('authUid'), username);
    if (existing) {
      return c.json({ ok: false, error: 'USERNAME_TAKEN' }, 409);
    }
    const passwordHash = await hashTagged(password);
    await db.insertAuthUser({
      tenant_id: c.get('authUid'),
      username,
      password_hash: passwordHash,
      role,
      display_name: displayName,
    });
    return c.json(
      { ok: true, data: { user: { username, role, display_name: displayName } } },
      201,
    );
  });

  app.patch('/admin/users/:username', requireOwner(), async (c) => {
    const db = deps.getDb(c.env);
    const username = c.req.param('username')!;
    const body = await c.req.json<{
      password?: string;
      display_name?: string;
      is_active?: number;
    }>();
    const existing = await db.getAuthUser(c.get('authUid'), username);
    if (!existing) {
      return c.json({ ok: false, error: 'USER_NOT_FOUND' }, 404);
    }
    if (body.password !== undefined && body.password.length < MIN_PASSWORD) {
      return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
    }
    await db.updateAuthUser(c.get('authUid'), username, {
      ...(body.password !== undefined
        ? { password_hash: await hashTagged(body.password) }
        : {}),
      ...(body.display_name !== undefined ? { display_name: body.display_name } : {}),
      ...(body.is_active !== undefined ? { is_active: body.is_active } : {}),
    });
    return c.json({ ok: true });
  });

  app.delete('/admin/users/:username', requireOwner(), async (c) => {
    const db = deps.getDb(c.env);
    const username = c.req.param('username')!;
    const existing = await db.getAuthUser(c.get('authUid'), username);
    if (!existing) {
      return c.json({ ok: false, error: 'USER_NOT_FOUND' }, 404);
    }
    // Soft-deactivate: the row stays for audit; login rejects is_active=0.
    await db.updateAuthUser(c.get('authUid'), username, { is_active: 0 });
    return c.json({ ok: true });
  });
}
