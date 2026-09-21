/**
 * TenantNotifier — Durable Object (no cloudflare:workers import).
 *
 * We don't import 'cloudflare:workers' because vitest can't resolve it.
 * Wrangler matches the class by name against wrangler.toml's
 * new_sqlite_classes so typing-vs-runtime is a non-issue.
 *
 * One DO per tenant (id = tenant uid). Holds hibernating WebSocket
 * connections for the admin dashboard and broadcasts sale/session events
 * pushed by daftari-api via service binding (env.REALTIME).
 *
 * WebSocket hibernation: state.acceptWebSocket allows the DO to sleep
 * while connections remain open — zero duration billing when idle.
 */
export class TenantNotifier {
  private readonly state: DurableObjectState;

  constructor(state: DurableObjectState, _env: unknown) {
    this.state = state;
    void _env;
    // Answer protocol pings without waking the DO (free).
    this.state.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
  }

  /** WebSocket upgrade hand-off from the worker route. */
  async fetch(request: Request): Promise<Response> {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair) as [WebSocket, WebSocket];
    this.state.acceptWebSocket(server);
    void request;
    return new Response(null, { status: 101, webSocket: client });
  }

  /** Call from daftari-api via service binding after a sale/sync event. */
  async notify(_tenantId: string, event: Record<string, unknown>): Promise<void> {
    const payload = JSON.stringify(event);
    for (const ws of this.state.getWebSockets()) {
      try {
        ws.send(payload);
      } catch {
        // Dead socket — cloudflare will surface cleanup via webSocketError.
      }
    }
  }

  async webSocketClose(ws: WebSocket): Promise<void> {
    try {
      ws.close();
    } catch {
      // Already closed
    }
  }

  async webSocketMessage(_ws: WebSocket, _message: ArrayBuffer | string): Promise<void> {
    void _message; // read-only channel — we never act on client messages
    void _ws;
  }
}

/** Exposed so wrangler.toml's new_sqlite_classes can see it. */
export default TenantNotifier;
