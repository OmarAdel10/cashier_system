/**
 * Users CRUD for the dashboard Users Management section (T07).
 *
 * GET/POST: any authenticated admin (owner or session). Creating
 * admin-role accounts is owner-only (spec §2.4: only the Firebase
 * owner creates/modifies admins; any admin creates cashiers).
 * PATCH/DELETE: owner-only.
 *
 * All business logic lives in application-layer use cases. Routes handle only
 * HTTP parsing, validation, delegation, and response formatting.
 *
 * NOTE: the /admin/* requireAuth middleware is registered by
 * registerAdmin() BEFORE this module — all routes here are protected.
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import type { TursoDb } from '../../../shared/src/turso';
import { hashTagged, MAX_PASSWORD, MIN_PASSWORD } from '../../../shared/src/password_kdf';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireOwner, requireAdmin } from '../middleware/auth';
import { UserListUseCase } from '../application/use-cases/user-list-use-case';
import { UserCreateUseCase } from '../application/use-cases/user-create-use-case';
import { UserUpdateUseCase } from '../application/use-cases/user-update-use-case';
import { UserDeleteUseCase } from '../application/use-cases/user-delete-use-case';
import type { UserCreateDto } from '../application/dtos/user-create.dto';
import type { UserUpdateDto } from '../application/dtos/user-update.dto';
import type { UserDeleteDto } from '../application/dtos/user-delete.dto';

const USERNAME_RE = /^[a-zA-Z0-9_]{3,30}$/;

/** Wire shape: never expose password_hash or lockout bookkeeping. */
function toWireUser(u: {
  tenantId: string;
  username: string;
  role: string;
  displayName?: string;
  mustChangePassword: number;
  isActive: number;
  createdAt: number;
  updatedAt: number;
}) {
  return {
    tenant_id: u.tenantId,
    username: u.username,
    role: u.role,
    display_name: u.displayName,
    must_change_password: u.mustChangePassword,
    is_active: u.isActive,
    created_at: u.createdAt,
    updated_at: u.updatedAt,
  };
}

export function registerUsers(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: {
    verifyToken?: VerifyTokenFn;
    getDb: (env: DbEnv) => TursoDb;
    userList: UserListUseCase;
    userCreate: UserCreateUseCase;
    userUpdate: UserUpdateUseCase;
    userDelete: UserDeleteUseCase;
  },
): void {
  const { userList, userCreate, userUpdate, userDelete } = deps;

  app.get('/admin/users', requireAdmin({ db: deps.getDb }), async (c) => {
    const tenantId = c.get('authUid');
    const result = await userList.execute({ tenantId });
    if (!result.ok) {
      return c.json({ ok: false, error: 'MISSING_FIELDS' }, 400);
    }
    return c.json({
      ok: true,
      data: {
        users: result.data.users.map(toWireUser),
      },
    });
  });

  app.post('/admin/users', async (c) => {
    const tenantId = c.get('authUid');
    const body = await c.req.json<{
      username?: unknown;
      password?: unknown;
      role?: unknown;
      display_name?: unknown;
    }>();
    // Runtime JSON type guards: a numeric password would pass a .length
    // check (undefined < 8 is false) and a numeric username would throw
    // on .trim() → 500 (T07 QA round 1, type confusion).
    if (
      typeof body.username !== 'string' ||
      typeof body.password !== 'string' ||
      typeof body.role !== 'string' ||
      (body.display_name !== undefined && typeof body.display_name !== 'string')
    ) {
      return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
    }
    const username = body.username.trim();
    const password = body.password;
    const role = body.role;
    const displayName = body.display_name?.trim() || undefined;
    if (
      !USERNAME_RE.test(username) ||
      password.length < MIN_PASSWORD ||
      password.length > MAX_PASSWORD ||
      (role !== 'admin' && role !== 'cashier')
    ) {
      return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
    }
    // Owner-only admin management (spec §2.4): session admins may only
    // create cashiers.
    if (role === 'admin' && c.get('authIsOwner') !== true) {
      return c.json({ ok: false, error: 'ADMIN_MANAGEMENT_OWNER_ONLY' }, 403);
    }

    const passwordHash = await hashTagged(password);

    const dto: UserCreateDto = {
      tenantId,
      username,
      passwordHash,
      role,
      displayName,
      isOwner: c.get('authIsOwner') === true,
    };

    const result = await userCreate.execute(dto);
    if (!result.ok) {
      switch (result.error) {
        case 'MISSING_FIELDS': return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
        case 'TIER_REQUIRED': return c.json({ ok: false, error: 'TIER_REQUIRED' }, 403);
        case 'ADMIN_MANAGEMENT_OWNER_ONLY': return c.json({ ok: false, error: 'ADMIN_MANAGEMENT_OWNER_ONLY' }, 403);
        case 'USERNAME_TAKEN': return c.json({ ok: false, error: 'USERNAME_TAKEN' }, 409);
        default: return c.json({ ok: false, error: 'INTERNAL_ERROR' }, 500);
      }
    }

    return c.json(
      { ok: true, data: { user: { username, role, display_name: result.data.display_name } } },
      201,
    );
  });

  app.patch('/admin/users/:username', requireOwner(), async (c) => {
    const username = c.req.param('username')!;
    const body = await c.req.json<{
      password?: unknown;
      display_name?: unknown;
      is_active?: unknown;
    }>();

    // Runtime type guards (T07 QA round 1 type confusion).
    if (
      (body.password !== undefined && typeof body.password !== 'string') ||
      (body.password !== undefined && (body.password.length < MIN_PASSWORD || body.password.length > MAX_PASSWORD)) ||
      (body.display_name !== undefined && body.display_name !== null && typeof body.display_name !== 'string') ||
      (body.is_active !== undefined && !Number.isInteger(body.is_active))
    ) {
      return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
    }

    const dto: UserUpdateDto = {
      tenantId: c.get('authUid'),
      username,
      passwordHash: body.password !== undefined ? await hashTagged(body.password) : undefined,
      displayName: body.display_name,
      isActive: typeof body.is_active === 'number' && (body.is_active === 0 || body.is_active === 1) ? body.is_active : undefined,
    };

    const result = await userUpdate.execute(dto);
    if (!result.ok) {
      switch (result.error) {
        case 'MISSING_FIELDS': return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
        case 'USER_NOT_FOUND': return c.json({ ok: false, error: 'USER_NOT_FOUND' }, 404);
        default: return c.json({ ok: false, error: 'INTERNAL_ERROR' }, 500);
      }
    }

    return c.json({ ok: true });
  });

  app.delete('/admin/users/:username', requireOwner(), async (c) => {
    const username = c.req.param('username')!;

    const dto: UserDeleteDto = {
      tenantId: c.get('authUid'),
      username,
    };

    const result = await userDelete.execute(dto);
    if (!result.ok) {
      switch (result.error) {
        case 'MISSING_FIELDS': return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
        case 'USER_NOT_FOUND': return c.json({ ok: false, error: 'USER_NOT_FOUND' }, 404);
        default: return c.json({ ok: false, error: 'INTERNAL_ERROR' }, 500);
      }
    }

    return c.json({ ok: true });
  });
}
