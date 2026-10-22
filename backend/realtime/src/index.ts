/**
 * daftari-realtime — Durable Object hub + WebSocket endpoint.
 *
 * POST /internal/notify: service binding from daftari-api; validates inputs
 * via NotifyUseCase, persists the broadcast event, then fans out to the
 * tenant's Durable Object (WebSocket hub).
 *
 * GET /ws: WebSocket upgrade endpoint for the admin dashboard. Authenticates
 * via `Authorization: Bearer` HS256 JWT (ADMIN_JWT_SECRET, per spec) or
 * short-lived ticket (?ticket=, validated via WebSocketConnectUseCase), then
 * proxies the upgrade to the DO. The DO owns hibernation + broadcast; this
 * route just parses, delegates, and formats responses.
 *
 * Since Durable Objects and service bindings are Cloudflare runtime
 * constructs, we keep them structural (`no cloudflare:workers` import) —
 * this lets vitest run the full worker surface in Node.
 */
import { Hono } from 'hono';

export { TenantNotifier } from './tenant_notifier';

import { BroadcastServiceImpl } from './domain/services/broadcast-service.impl';
import { TicketValidationServiceImpl } from './domain/services/ticket-validation-service.impl';
import { RateLimiter } from './infrastructure/services/rate-limiter';
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
  /** Verifies dashboard session JWTs on the /ws upgrade (same value as api). */
  ADMIN_JWT_SECRET: string;
  /** Shared secret required on /internal/notify (same value as api worker). */
  INTERNAL_NOTIFY_SECRET: string;
  /** Turso (libSQL) database URL. */
  TURSO_DB_URL: string;
  /** Turso (libSQL) database authentication token. */
  TURSO_DB_AUTH_TOKEN: string;
}

export interface RealtimeDeps {
  broadcastService?: BroadcastService;
  broadcastRepo?: BroadcastRepository;
  ticketValidationService?: TicketValidationService;
  ticketRepo?: RealtimeTicketRepository;
  rateLimiter?: RateLimiter;
}

/** Constant-time string comparison to prevent timing side-channels. */
function constantTimeEqual(a: string, b: string): boolean {
  const len = Math.max(a.length, b.length);
  let result = 0;
  for (let i = 0; i < len; i += 1) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

/** Base64url-decode a JWT part without padding. */
function b64urlDecode(part: string): Uint8Array {
  const normalized = part.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

/** tenantId format: lowercase alphanumeric, hyphens, underscores only. */
const TENANT_ID_RE = /^[a-z0-9_-]+$/;
/** Max tenantId length. */
const MAX_TENANT_ID_LENGTH = 128;
/** Clock-skew leeway (seconds) for JWT exp/nbf comparisons. */
const CLOCK_SKEW_SECONDS = 60;

/** Reject non-string tenantId before coercion. */
function isStringTenantId(raw: unknown): raw is string {
  return typeof raw === 'string';
}

/** Validate tenantId format (cross-tenant routing key / IDOR guard). */
function validateTenantId(tenantId: string): boolean {
  return (
    tenantId.length > 0 &&
    tenantId.length <= MAX_TENANT_ID_LENGTH &&
    TENANT_ID_RE.test(tenantId)
  );
}

/**
 * Verify an HS256 JWT signed with the shared secret, returning its payload.
 *
 * Validates: HS256 algorithm, signature, exp, nbf, aud, iss.
 * Issuer/audience are hardcoded to the realtime service to prevent
 * cross-service JWT confusion.
 */
async function verifyHs256Jwt(
  token: string,
  secret: string,
): Promise<{ valid: boolean; payload?: Record<string, unknown> }> {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return { valid: false };
    const header = JSON.parse(
      new TextDecoder().decode(b64urlDecode(parts[0]!)),
    ) as { alg?: string };
    if (header.alg !== 'HS256') return { valid: false };
    const payload = JSON.parse(
      new TextDecoder().decode(b64urlDecode(parts[1]!)),
    ) as Record<string, unknown>;

    // exp: require presence; reject tokens past expiry (with clock-skew leeway).
    const nowSec = Math.floor(Date.now() / 1000);
    if (typeof payload.exp !== 'number' || payload.exp <= nowSec - CLOCK_SKEW_SECONDS) {
      return { valid: false };
    }
    // nbf: require presence; reject tokens not yet valid (with clock-skew leeway).
    if (typeof payload.nbf !== 'number' || payload.nbf > nowSec + CLOCK_SKEW_SECONDS) {
      return { valid: false };
    }
    // aud: reject tokens not intended for this service.
    if (payload.aud !== 'realtime') return { valid: false };
    // iss: reject tokens not issued by this service.
    if (payload.iss !== 'daftari-realtime') return { valid: false };

    const signature = b64urlDecode(parts[2]!);
    const data = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify'],
    );
    const valid = await crypto.subtle.verify('HMAC', key, signature, data);
    return { valid: valid as boolean, payload };
  } catch {
    return { valid: false };
  }
}

export function createRealtimeApp(deps: RealtimeDeps = {}) {
  const broadcastService = deps.broadcastService ?? new BroadcastServiceImpl();
  const broadcastRepo = deps.broadcastRepo ?? new InMemoryBroadcastRepository();
  const ticketValidationService =
    deps.ticketValidationService ?? new TicketValidationServiceImpl();
  const ticketRepo = deps.ticketRepo ?? new InMemoryRealtimeTicketRepository();
  const rateLimiter = deps.rateLimiter ?? new RateLimiter(100, 60_000);

  const notifyUseCase = new NotifyUseCase(broadcastService, broadcastRepo);
  const wsConnectUseCase = new WebSocketConnectUseCase(
    ticketValidationService,
    ticketRepo,
  );

  const app = new Hono<{ Bindings: Env }>();

  app.post('/internal/notify', async (c) => {
    // Reject oversized bodies before parsing (DoS guard).
    const bodyText = await c.req.raw.text();
    if (new TextEncoder().encode(bodyText).length > 256 * 1024) {
      return c.json({ ok: false, error: 'PAYLOAD_TOO_LARGE' }, 413);
    }

    const secret = c.req.header('X-Internal-Secret') ?? '';
    const expectedSecret = c.env.INTERNAL_NOTIFY_SECRET ?? '';
    if (
      !expectedSecret ||
      !constantTimeEqual(secret, expectedSecret)
    ) {
      return c.json({ ok: false, error: 'Unauthorized' }, 401);
    }

    let body: Record<string, unknown>;
    try {
      body = JSON.parse(bodyText);
    } catch {
      return c.json({ ok: false, error: 'Invalid JSON' }, 400);
    }
    if (body === null || typeof body !== 'object' || Array.isArray(body)) {
      return c.json({ ok: false, error: 'Invalid JSON' }, 400);
    }

    const rawTenantId = body['tenantId'];
    if (!isStringTenantId(rawTenantId)) {
      return c.json({ ok: false, error: 'INVALID_TENANT' }, 400);
    }
    const tenantId = rawTenantId;

    // Validate tenantId presence (empty = missing).
    if (tenantId.length === 0) {
      return c.json({ ok: false, error: 'MISSING_TENANT' }, 400);
    }
    // Validate tenantId format (IDOR guard: tenantId routes to a Durable Object).
    if (!validateTenantId(tenantId)) {
      return c.json({ ok: false, error: 'INVALID_TENANT' }, 400);
    }

    // Rate limit per caller (global key, DoS guard — not keyed on caller-supplied tenantId).
    const rateResult = rateLimiter.check('realtime-notify');
    if (!rateResult.allowed) {
      return c.json(
        { ok: false, error: 'RATE_LIMITED', retryAfterMs: rateResult.retryAfterMs },
        429,
      );
    }

    const result = await notifyUseCase.execute({
      tenantId,
      event:
        typeof body['event'] === 'string'
          ? body['event']
          : String(body['event'] ?? ''),
      data:
        body['data'] && typeof body['data'] === 'object' && !Array.isArray(body['data'])
          ? (body['data'] as Record<string, unknown>)
          : undefined,
    });

    if (!result.ok) {
      return c.json({ ok: false, error: result.error }, 400);
    }

    // Fan out to the tenant's WebSocket sessions via the Durable Object.
    const payload = result.data.payload;
    // Use validated tenantId (not payload.tenantId) for DO routing — IDOR guard.
    const stub = c.env.NOTIFIER.get(c.env.NOTIFIER.idFromName(tenantId));
    try {
      await stub.notify(tenantId, payload as unknown as Record<string, unknown>);
    } catch {
      // Fan-out failure: event persisted but not delivered. Return 503 so
      // the caller can retry; the broadcast record remains for audit/replay.
      return c.json({ ok: false, error: 'BROADCAST_FANOUT_FAILED' }, 503);
    }
    return c.json({ ok: true, broadcastId: result.data.broadcastId });
  });

  app.get('/ws', async (c) => {
    const url = new URL(c.req.raw.url);

    // Pre-auth rate limit: strict per-IP bucket (protects auth boundary from
    // guessing / connection DoS by unauthenticated clients).
    // Only CF-Connecting-IP is trusted (Cloudflare-managed); X-Real-IP is
    // spoofable by clients and must not be used for rate-limit keying.
    const clientIp = c.req.header('CF-Connecting-IP');
    if (!clientIp) {
      return c.json({ ok: false, error: 'Missing client IP' }, 400);
    }
    const preAuthResult = rateLimiter.check(`ws-preauth:${clientIp}`);
    if (!preAuthResult.allowed) {
      return c.json(
        { ok: false, error: 'RATE_LIMITED', retryAfterMs: preAuthResult.retryAfterMs },
        429,
      );
    }

    const authHeader = c.req.header('Authorization') ?? '';
    const ticket = url.searchParams.get('ticket');

    // No credential at all → 401 before any upgrade check.
    if (!authHeader.startsWith('Bearer ') && !ticket) {
      return c.json({ ok: false, error: 'Missing ticket' }, 401);
    }

    // Reject non-WebSocket upgrades before consuming any credentials.
    const upgrade = c.req.header('Upgrade');
    if (upgrade !== 'websocket') {
      return c.json({ ok: false, error: 'Upgrade required' }, 426);
    }

    let tenantId: string;

    // Prefer Authorization: Bearer JWT (spec: PRD.md /ws auth).
    if (authHeader.startsWith('Bearer ')) {
      const jwt = await verifyHs256Jwt(authHeader.slice(7), c.env.ADMIN_JWT_SECRET);
      if (
        !jwt.valid ||
        !jwt.payload ||
        typeof jwt.payload.tenantId !== 'string' ||
        !validateTenantId(jwt.payload.tenantId)
      ) {
        return c.json({ ok: false, error: 'Invalid or expired ticket' }, 401);
      }
      tenantId = jwt.payload.tenantId;
    } else {
      // Fall back to short-lived ticket (?ticket=).
      const result = await wsConnectUseCase.execute({ ticket: ticket! });
      if (!result.ok) {
        return c.json({ ok: false, error: 'Invalid or expired ticket' }, 401);
      }
      tenantId = result.data.tenantId;
      if (!validateTenantId(tenantId)) {
        return c.json({ ok: false, error: 'Invalid or expired ticket' }, 401);
      }
    }

    // Post-auth rate limit: per-tenant bucket (higher limit for authenticated clients).
    const postAuthResult = rateLimiter.check(`ws-authed:${tenantId}`);
    if (!postAuthResult.allowed) {
      return c.json(
        { ok: false, error: 'RATE_LIMITED', retryAfterMs: postAuthResult.retryAfterMs },
        429,
      );
    }

    const id = c.env.NOTIFIER.idFromName(tenantId);
    const stub = c.env.NOTIFIER.get(id);
    // TODO(Phase 5/6): DO-level re-authorization — validate caller identity/tenant
    // binding inside TenantNotifier.fetch() to prevent cross-tenant WS access.
    return stub.fetch(c.req.raw);
  });

  return app;
}
