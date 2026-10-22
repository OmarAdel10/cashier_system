/**
 * Data Transfer Object for the /ws WebSocket connection request.
 *
 * Carries the single piece of client-supplied input needed to authenticate
 * a WebSocket connection: the short-lived ticket issued by the API.
 */
export interface WebSocketConnectDto {
  /** Opaque ticket string from the ?ticket= query parameter. */
  readonly ticket: string;
}

/**
 * WebSocket connect use case response — discriminated union.
 *
 * On success: ok=true with the resolved tenantId (used to route to the
 * tenant's Durable Object).
 * On failure: ok=false with an error code.
 */
export type WebSocketConnectResponse =
  | {
      ok: true;
      data: {
        /** Tenant the ticket was issued for. */
        tenantId: string;
      };
      error?: never;
    }
  | {
      ok: false;
      error:
        | 'MISSING_TICKET'
        | 'INVALID_TICKET'
        | 'EXPIRED_TICKET'
        | 'ALREADY_USED_TICKET'
        | 'VALIDATION_FAILED';
      retryAfterMs?: number;
    };
