/**
 * daftari-realtime runtime entry point.
 *
 * Wires the shared Turso-backed RealtimeTicketRepository with realtime-specific
 * services (BroadcastService, TicketValidationService, NotifyUseCase,
 * WebSocketConnectUseCase, RateLimiter) and exports a fully-wired
 * createRealtimeApp() for the Cloudflare Worker runtime.
 *
 * The Durable Object binding (NOTIFIER) and Turso DB credentials come from
 * wrangler.toml environment variables/secrets.
 */
import { createTurso } from '../../shared/src/turso';
import { TursoRealtimeTicketRepository } from '../../shared/src/infrastructure/repositories/turso-realtime-ticket-repository';
import { BroadcastServiceImpl } from './domain/services/broadcast-service.impl';
import { TicketValidationServiceImpl } from './domain/services/ticket-validation-service.impl';
import { RateLimiter } from './infrastructure/services/rate-limiter';
import { InMemoryBroadcastRepository } from './infrastructure/repositories/in-memory-broadcast-repository';
import { NotifyUseCase } from './application/use-cases/notify-use-case';
import { WebSocketConnectUseCase } from './application/use-cases/websocket-connect-use-case';
import { createRealtimeApp, type RealtimeDeps, type Env } from './index';

/**
 * Build a fully-wired createRealtimeApp from the Worker environment.
 *
 * Resolves the shared TursoRealtimeTicketRepository (atomic ticket validation:
 * expiry + single-use + tenant lookup) and constructs all realtime use cases
 * with injected dependencies.
 *
 * @param env - Cloudflare Worker environment bindings (NOTIFIER DO,
 *   ADMIN_JWT_SECRET, INTERNAL_NOTIFY_SECRET, TURSO_DB_URL,
 *   TURSO_DB_AUTH_TOKEN)
 * @returns A Hono app with all routes wired to use cases
 */
export function createRealtimeAppFromEnv(env: Env) {
  // Fail closed: required env vars must be present before constructing the app.
  if (!env.TURSO_DB_URL || !env.TURSO_DB_AUTH_TOKEN) {
    throw new Error(
      'Missing required env vars: TURSO_DB_URL and TURSO_DB_AUTH_TOKEN',
    );
  }
  if (!env.ADMIN_JWT_SECRET) {
    throw new Error('Missing required env var: ADMIN_JWT_SECRET');
  }
  if (!env.INTERNAL_NOTIFY_SECRET) {
    throw new Error('Missing required env var: INTERNAL_NOTIFY_SECRET');
  }

  const db = createTurso(env.TURSO_DB_URL, env.TURSO_DB_AUTH_TOKEN);
  const ticketRepo = new TursoRealtimeTicketRepository(db);
  const broadcastRepo = new InMemoryBroadcastRepository();
  const ticketValidationService = new TicketValidationServiceImpl();
  const broadcastService = new BroadcastServiceImpl();
  const rateLimiter = new RateLimiter(100, 60_000);

  const deps: RealtimeDeps = {
    broadcastService,
    broadcastRepo,
    ticketValidationService,
    ticketRepo,
    rateLimiter,
  };

  return createRealtimeApp(deps);
}

export default createRealtimeAppFromEnv;
