/**
 * Admin routes: read-only overview for the web admin dashboard.
 * Requires role='admin' (cashiers or unknown users → 403).
 *
 * All business logic lives in application-layer use cases. Routes handle only
 * HTTP parsing, validation, delegation, and response formatting.
 *
 * Wiring precondition: identity fields (tenantId) must be sourced ONLY from
 * verified middleware context (c.get('authUid')), never from request body
 * or query/header.
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import type { TursoDb } from '../../../shared/src/turso';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireAdmin, requireOwner, requireAuth } from '../middleware/auth';
import { AdminSettingsUseCase } from '../application/use-cases/admin-settings-use-case';
import { DeviceLinkUseCase } from '../application/use-cases/device-link-use-case';
import { registerDevices } from './devices';

export function registerAdmin(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: {
    verifyToken?: VerifyTokenFn;
    getDb: (env: DbEnv) => TursoDb;
    adminSettings: AdminSettingsUseCase;
    deviceLink: DeviceLinkUseCase;
  },
): void {
  const { adminSettings } = deps;

  app.use('/admin/*', requireAuth({ verifyToken: deps.verifyToken, db: deps.getDb }));
  app.use('/admin/*', requireAdmin({ db: deps.getDb }));

  app.get('/admin/overview', async (c) => {
    const tenantId = c.get('authUid');
    const result = await adminSettings.execute({ tenantId });
    if (!result.ok) {
      switch (result.error) {
        case 'MISSING_FIELDS': return c.json({ ok: false, error: 'MISSING_FIELDS' }, 400);
        case 'USER_NOT_FOUND': return c.json({ ok: false, error: 'USER_NOT_FOUND' }, 404);
        case 'NO_LICENSE': return c.json({ ok: false, error: 'NO_LICENSE' }, 401);
        default: return c.json({ ok: false, error: 'INTERNAL_ERROR' }, 500);
      }
    }
    return c.json({
      ok: true,
      data: {
        tenant_id: tenantId,
        tier: result.data.tier,
        device_limit: result.data.deviceLimit,
        license_status: result.data.licenseStatus,
      },
    });
  });

  // Register the devices linking route (owner-only)
  registerDevices(app, {
    verifyToken: deps.verifyToken,
    getDb: deps.getDb,
    deviceLink: deps.deviceLink,
  });

  /** Devices view for the dashboard: device cards + the active POS session
   *  per device. Web session rows (device_hwid 'web') have no devices row,
   *  so they never appear here (T06 QA F1 note). */
  app.get('/admin/devices', async (c) => {
    const db = deps.getDb(c.env);
    const uid = c.get('authUid');
    const devices = await db.listDevices(uid);
    const active = await db.getActiveSessions(uid);
    const byHwid = new Map(active.map((s) => [s.deviceHwid, s]));
    return c.json({
      ok: true,
      data: {
        devices: devices.map((d) => {
          const session = byHwid.get(d.deviceHwid);
          return {
            tenant_id: d.tenantId,
            device_hwid: d.deviceHwid,
            device_name: d.deviceName,
            platform: d.platform,
            first_seen_at: d.firstSeenAt,
            last_seen_at: d.lastSeenAt,
            active_session: session
              ? { id: session.id, username: session.username, started_at: session.startedAt }
              : undefined,
          };
        }),
      },
    });
  });

  /** Recent activity feed: latest sales + sessions merged, newest first. */
  app.get('/admin/activity', async (c) => {
    const db = deps.getDb(c.env);
    const uid = c.get('authUid');
    const [sales, sessions] = await Promise.all([
      db.getRecentSales(uid, 5),
      db.getRecentSessions(uid, 5),
    ]);
    const events = [
      ...sales.map((s) => ({
        type: 'sale' as const,
        at: s.createdAt,
        summary: `${s.totalPiastres} piastres`,
      })),
      ...sessions.map((s) => ({
        type: 'session' as const,
        at: s.startedAt,
        summary: `${s.username} on ${s.deviceHwid}`,
      })),
    ]
      .sort((a, b) => b.at - a.at)
      .slice(0, 10);
    return c.json({ ok: true, data: { events } });
  });
}
