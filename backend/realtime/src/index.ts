/**
 * daftari-realtime — Durable Object hub + WebSocket endpoint.
 *
 * POST /internal/notify: service binding from daftari-api; validates inputs
 * via NotifyUseCase, persists the broadcast event, then fans out to the
 * tenant's Durable Object (WebSocket hub).
 *
 * GET /ws: WebSocket upgrade endpoint for the admin dashboard. Validates the
 * ticket via WebSocketConnectUseCase, then proxies the upgrade to the DO.
 * The DO owns hibernation + broadcast; this route just parses, delegates,
 * and formats responses.
 *
 * Since Durable Objects and service bindings are Cloudflare runtime
 * constructs, we keep them structural (`no cloudflare:workers` import) —
 * this lets vitest run the full worker surface in Node.
 */
import { Hono } from 'hono';
import type { Context } from 'hono';

export { TenantNotifier } from './tenant_notifier';

import { BroadcastServiceImpl } from './domain/services/broadcast-service.impl';
import { TicketValidationServiceImpl } from './domain/services/ticket-validation-service.impl';
import { InMemoryBroadcastRepository } from './infrastructure/repositories/in-memory-broadcast-repository';
import { InMemoryRealtimeTicketRepository } from './infrastructure/repositories/in-memory-realtime-ticket-repository';
import { NotifyUseCase } from './application/use-cases/notify-use-case';
import { WebSocketConnectUseCase } from './application/use-cases/websocket-connect-use-case';
import type { BroadcastService } from './domain/services/broadcast-service';
import type { BroadcastRepository } from './domain/repositories/broadcast-repository';
import type { TicketValidationService } from './domain/services/ticket-validation-service';
import type { RealtimeTicketRepository } from '../../shared/src/domain/repositories/realtime-ticket-repository';

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
  /** Base URL of the API worker (for ticket validation). */
  API_URL: string;
}

export interface RealtimeDeps {
  broadcastService?: BroadcastService;
  broadcastRepo?: BroadcastRepository;
  ticketValidationService?: TicketValidationService;
  ticketRepo?: RealtimeTicketRepository;
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
  const broadcastService = deps.broadcastService ?? new BroadcastServiceImpl();
  const broadcastRepo = deps.broadcastRepo ?? new InMemoryBroadcastRepository();
  const ticketValidationService =
    deps.ticketValidationService ?? new TicketValidationServiceImpl();
  const ticketRepo = deps.ticketRepo ?? new InMemoryRealtimeTicketRepository();

  const notifyUseCase = new NotifyUseCase(broadcastService, broadcastRepo);
  const wsConnectUseCase = new WebSocketConnectUseCase(ticketValidationService, ticketRepo);

  const app = new Hono<{ Bindings: Env }>();

  app.post('/internal/notify', async (c) => {
    const secret = c.req.header('X-Internal-Secret');
    if (!c.env.INTERNAL_NOTIFY_SECRET || secret !== c.env.INTERNAL_NOTIFY_SECRET) {
      return c.json({ ok: false, error: 'Unauthorized' }, 401);
    }

    const body = await c.req.json<Record<string, unknown>>();
    const result = await notifyUseCase.execute({
      tenantId: String(body['tenantId'] ?? ''),
      event: String(body['event'] ?? ''),
      data: body['data'] as Record<string, unknown> | undefined,
    });

    if (!result.ok) {
      return c.json({ ok: false, error: result.error }, 400);
    }

    // Fan out to the tenant's WebSocket sessions via the Durable Object.
    const stub = c.env.NOTIFIER.get(c.env.NOTIFIER.idFromName(result.data.payload.tenantId));
    await stub.notify(result.data.payload.tenantId, result.data.payload as unknown as Record<string, unknown>);
    return c.json({ ok: true, broadcastId: result.data.broadcastId });
  });

  app.get('/ws', async (c) => {
    const url = new URL(c.req.raw.url);
    const ticket = url.searchParams.get('ticket');
    if (!ticket) {
      return c.json({ ok: false, error: 'Missing ticket' }, 401);
    }

    const result = await wsConnectUseCase.execute({ ticket });
    if (!result.ok) {
      return c.json({ ok: false, error: 'Invalid or expired ticket' }, 401);
    }

    const upgrade = c.req.header('Upgrade');
    if (upgrade !== 'websocket') return c.json({ ok: false, error: 'Upgrade required' }, 426);

    const id = c.env.NOTIFIER.idFromName(result.data.tenantId);
    const stub = c.env.NOTIFIER.get(id);
    return stub.fetch(c.req.raw);
  });

  return app;
}

export default createRealtimeApp();
