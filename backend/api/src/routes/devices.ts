/**
 * Device linking route for the admin dashboard (T40 / DAFTARI-86).
 * Owner-only: links a device (device_hwid + name) to the tenant.
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import type { TursoDb } from '../../../shared/src/turso';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireOwner } from '../middleware/auth';
import type { DeviceRecord } from '../../../shared/src/types';

/** Validation schema for the link request body. */
export const upsertDeviceSchema = {
  device_hwid: (v: unknown): v is string =>
    typeof v === 'string' && v.length >= 1 && v.length <= 128,
  device_name: (v: unknown): v is string =>
    typeof v === 'string' && v.length >= 1 && v.length <= 64,
  platform: (v: unknown): v is string =>
    typeof v === 'string' && v.length <= 32,
};

/** Wire shape for device response. */
function toWireDevice(d: DeviceRecord) {
  return {
    tenant_id: d.tenant_id,
    device_hwid: d.device_hwid,
    device_name: d.device_name,
    platform: d.platform,
    first_seen_at: d.first_seen_at,
    last_seen_at: d.last_seen_at,
  };
}

export function registerDevices(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: { verifyToken?: VerifyTokenFn; getDb: (env: DbEnv) => TursoDb },
): void {
  // Owner-only: the device-linking wizard requires an owner token.
  app.post('/admin/devices/link', requireOwner(), async (c) => {
    const db = deps.getDb(c.env);
    const tenantId = c.get('authUid');

    const body = await c.req.json<{
      device_hwid?: unknown;
      device_name?: unknown;
      platform?: unknown;
    }>();

    if (!upsertDeviceSchema.device_hwid(body.device_hwid)) {
      return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
    }
    const deviceName = upsertDeviceSchema.device_name(body.device_name)
      ? body.device_name!.trim()
      : undefined;
    const platform = upsertDeviceSchema.platform(body.platform)
      ? body.platform!.trim()
      : undefined;

    if (deviceName !== undefined && deviceName === '') {
      return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
    }
    if (platform !== undefined && platform === '') {
      return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
    }

    const now = Date.now();
    await db.upsertDevice({
      tenant_id: tenantId,
      device_hwid: body.device_hwid!,
      device_name: deviceName,
      platform,
      first_seen_at: now,
      last_seen_at: now,
    });

    const device = await db.listDevices(tenantId).then((ds) =>
      ds.find((d) => d.device_hwid === body.device_hwid),
    );

    return c.json(
      { ok: true, data: { device: device ? toWireDevice(device) : null } },
      201,
    );
  });
}