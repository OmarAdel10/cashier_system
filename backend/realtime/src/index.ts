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
import { verifyFirebaseToken } from '../../shared/src/jwt';

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
export function createRealtimeApp(deps: RealtimeDeps = {}) {
  const verify = deps.verifyToken ?? verifyFirebaseToken;
  const app = new Hono<{ Bindings: Env }>();

  app.post('/internal/notify', async (c) => {
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
    const authHeader = c.req.header('Authorization') ?? '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
    if (!token) return c.json({ ok: false, error: 'Missing bearer token' }, 401);

    const result = await verify(token, c.env.FIREBASE_PROJECT_ID);
    if (!result.valid || !result.uid) {
      return c.json({ ok: false, error: 'Invalid token' }, 401);
    }

    const upgrade = c.req.header('Upgrade');
    if (upgrade !== 'websocket') return c.json({ ok: false, error: 'Upgrade required' }, 426);

    const id = c.env.NOTIFIER.idFromName(result.uid);
    const stub = c.env.NOTIFIER.get(id);
    return stub.fetch(c.req.raw);
  });

  return app;
}

export default createRealtimeApp();
