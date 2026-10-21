/**
 * Device linking route for the admin dashboard (T40 / DAFTARI-86).
 * Owner-only: links a device (device_hwid + name) to the tenant.
 *
 * All business logic lives in DeviceLinkUseCase. The route handles only
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
import { requireOwner } from '../middleware/auth';
import { DeviceLinkUseCase } from '../application/use-cases/device-link-use-case';
import type { DeviceLinkDto } from '../application/dtos/device-link.dto';
import { validateDeviceHwid } from '../application/validation';

export function registerDevices(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: {
    verifyToken?: VerifyTokenFn;
    getDb: (env: DbEnv) => TursoDb;
    deviceLink: DeviceLinkUseCase;
  },
): void {
  const { deviceLink } = deps;

  // Owner-only: the device-linking wizard requires an owner token.
  app.post('/admin/devices/link', requireOwner(), async (c) => {
    const tenantId = c.get('authUid');
    const body = await c.req.json<{
      device_hwid?: unknown;
      device_name?: unknown;
      platform?: unknown;
    }>();

    const deviceHwid = body.device_hwid;
    if (!validateDeviceHwid(deviceHwid)) {
      return c.json({ ok: false, error: 'INVALID_FIELDS' }, 400);
    }
    const deviceName =
      typeof body.device_name === 'string'
        ? body.device_name.trim() || undefined
        : undefined;
    const platform =
      typeof body.platform === 'string'
        ? body.platform.trim() || undefined
        : undefined;

    const dto: DeviceLinkDto = {
      tenantId,
      deviceHwid,
      deviceName,
      platform,
    };

    const result = await deviceLink.execute(dto);
    if (!result.ok) {
      return c.json({ ok: false, error: 'MISSING_FIELDS' }, 400);
    }

    return c.json(
      {
        ok: true,
        data: {
          device: {
            device_hwid: result.data.deviceHwid,
            device_name: result.data.device_name,
            platform: result.data.platform,
            first_seen_at: result.data.first_seen_at,
            last_seen_at: result.data.last_seen_at,
          },
        },
      },
      201,
    );
  });
}
