/**
 * Branding routes: upload + serve tenant logo SVGs via R2.
 *
 * Validation is minimal by design: SVG string length (≤256 KiB), no
 * <script> tags, no event-handler attributes (on*). The stored file is
 * served with Content-Type image/svg+xml and 1h cache.
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import type { TursoDb } from '../../../shared/src/turso';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireAuth } from '../middleware/auth';

const MAX_SVG_BYTES = 256 * 1024;

/** Validates a provided SVG string; returns an error message or null. */
export function validateSvg(svg: string): string | null {
  const trimmed = svg.trim();
  if (trimmed.length === 0) return 'SVG is empty';
  if (trimmed.length > MAX_SVG_BYTES) return 'SVG too large';
  if (!trimmed.startsWith('<svg') && !trimmed.startsWith('<?xml')) {
    return 'SVG must start with <svg or an XML declaration';
  }
  if (/<script/i.test(svg)) return 'SVG contains a script tag';
  if (/\son[a-z]+\s*=/i.test(svg)) return 'SVG contains event-handler attributes';
  return null;
}

export function registerBranding(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: { verifyToken?: VerifyTokenFn; getDb: (env: DbEnv) => TursoDb },
): void {
  app.use('/branding/logo', requireAuth({ verifyToken: deps.verifyToken, db: deps.getDb }));

  app.post('/branding/logo', async (c) => {
    if (!c.env.LOGOS) {
      return c.json({ ok: false, error: 'Branding storage not configured' }, 500);
    }
    const body = await c.req.json<{ svg?: string }>();
    const svg = body.svg ?? '';
    const error = validateSvg(svg);
    if (error) return c.json({ ok: false, error }, 422);

    const key = `logos/${c.get('authUid')}.svg`;
    await c.env.LOGOS.put(key, svg, {
      httpMetadata: { contentType: 'image/svg+xml' },
    });
    return c.json({ ok: true, data: { key } });
  });

  app.get('/branding/logo/:tenantId', async (c) => {
    if (!c.env.LOGOS) {
      return c.json({ ok: false, error: 'Branding storage not configured' }, 500);
    }
    const key = `logos/${c.req.param('tenantId')}.svg`;
    const file = await c.env.LOGOS.get(key);
    if (!file) return c.json({ ok: false, error: 'Logo not found' }, 404);
    return new Response(file.body, {
      status: 200,
      headers: { 'Content-Type': 'image/svg+xml', 'Cache-Control': 'public, max-age=3600' },
    });
  });
}
