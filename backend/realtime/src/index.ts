/**
 * daftari-realtime — Durable Object hub + WebSocket endpoint.
 *
 * POST /internal/notify: service binding from daftari-api; fans out a
 * sale/session event to the tenant's Durable Object (WebSocket hub).
 *
 * GET /ws: WebSocket upgrade endpoint for the admin dashboard. The DO
 * owns hibernation + broadcast; this route just proxies to the stub.
 *
 * Since Durable Objects and service bindings are Cloudflare runtime
 * constructs, we keep them structural (`no cloudflare:workers` import) —
 * this lets vitest run the full worker surface in Node.
 */
import { Hono } from 'hono';
import type { Context } from 'hono';
import { verifyFirebaseToken } from '../../shared/src/jwt';
import { verifySessionJwt } from '../../shared/src/session_jwt';
import { b64urlToJson } from '../../shared/src/base64';

// Wrangler requires DO classes bound in wrangler.toml to be exported from
// the entrypoint. Re-export only — the class implementation stays put.
export { TenantNotifier } from './tenant_notifier';

/** Pojo that matches the DO stub's public API. */
export interface TaftariDurableObjectStub {
  fetch: (req: Request) => Promise<Response>;
  notify: (tenantId: string, event: Record<string, unknown>) => Promise<void>;
}

export interface Env {
  NOTIFIER: {
    /** Get a tenant-scoped DO stub; name is the tenant uid. */
    idFromName: (name: string) => string;
    /** Fetch a DO stub by name (called repeatedly for the same id). */
    get: (id: string) => TaftariDurableObjectStub;
  };
  FIREBASE_PROJECT_ID: string;
  ENVIRONMENT?: string;
  /** Verifies dashboard session JWTs on the /ws upgrade (same value as api). */
  ADMIN_JWT_SECRET: string;
  /** Shared secret required on /internal/notify (same value as api worker). */
  INTERNAL_NOTIFY_SECRET: string;
}

export interface RealtimeDeps {
  verifyToken?: (
    token: string,
    projectId: string,
  ) => Promise<{ valid: boolean; uid?: string; email?: string }>;
}

/**
 * Service binding shape (service name in wrangler.toml):
 * - /internal/notify — used by daftari-api sales route
 * - fetch — the admin dashboard's WebSocket connection
 */
/** Best-effort decode of the token header's alg field (no signature use). */
function tokenAlg(token: string): string | null {
  try {
    const alg = b64urlToJson(token.split('.')[0] ?? '')['alg'];
    return typeof alg === 'string' ? alg : null;
  } catch {
    return null;
  }
}

/**
 * Resolve the /ws credential: prefer `Authorization: Bearer`, fall back to
 * `?token=`. Browsers cannot set headers on a WebSocket, so the dashboard
 * sends ?token=.
 */
export function readWsToken(c: Context): string {
  const authHeader = c.req.header('Authorization') ?? '';
  if (authHeader.startsWith('Bearer ')) return authHeader.slice(7);
  return c.req.query('token') ?? '';
}

export function createRealtimeApp(deps: RealtimeDeps = {}) {
  const verify = deps.verifyToken ?? verifyFirebaseToken;
  const app = new Hono<{ Bindings: Env }>();

  app.post('/internal/notify', async (c) => {
    const secret = c.req.header('X-Internal-Secret');
    if (!c.env.INTERNAL_NOTIFY_SECRET || secret !== c.env.INTERNAL_NOTIFY_SECRET) {
      return c.json({ ok: false, error: 'Unauthorized' }, 401);
    }

    const body = await c.req.json<Record<string, unknown>>();
    const tenantId = String(body['tenantId'] ?? '');
    const event = String(body['event'] ?? '');
    const data = body['data'] as Record<string, unknown> | undefined;
    if (!tenantId) return c.json({ ok: false, error: 'missing tenantId' }, 400);

    const stub = c.env.NOTIFIER.get(c.env.NOTIFIER.idFromName(tenantId));
    await stub.notify(tenantId, { type: event, ...data, tenantId });
    return c.json({ ok: true });
  });

  app.get('/ws', async (c) => {
    const token = readWsToken(c);
    if (!token) return c.json({ ok: false, error: 'Missing bearer token' }, 401);

    // Dual-token: worker-minted session JWT (HS256, dashboard admins) or
    // Firebase ID token (RS256, owner) — mirrors the api middleware.
    let tenantId: string;
    if (tokenAlg(token) === 'HS256') {
      const claims = await verifySessionJwt(token, c.env.ADMIN_JWT_SECRET);
      if (!claims) return c.json({ ok: false, error: 'Invalid session token' }, 401);
      tenantId = claims.tid;
    } else {
      const result = await verify(token, c.env.FIREBASE_PROJECT_ID);
      if (!result.valid || !result.uid) {
        return c.json({ ok: false, error: 'Invalid token' }, 401);
      }
      tenantId = result.uid;
    }

    const upgrade = c.req.header('Upgrade');
    if (upgrade !== 'websocket') return c.json({ ok: false, error: 'Upgrade required' }, 426);

    const id = c.env.NOTIFIER.idFromName(tenantId);
    const stub = c.env.NOTIFIER.get(id);
    return stub.fetch(c.req.raw);
  });

  return app;
}

export default createRealtimeApp();
