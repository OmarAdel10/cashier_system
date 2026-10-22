/**
 * Data Transfer Object for the /internal/notify request.
 *
 * Carries the service-binding payload from daftari-api: a tenant-scoped
 * event to fan out to the tenant's connected WebSocket sessions.
 */
export interface NotifyUseCaseDto {
  /** Tenant the event belongs to (resolved by the API caller, trusted). */
  readonly tenantId: string;
  /** Event type, e.g. 'sale' | 'session' | 'sync'. */
  readonly event: string;
  /** Arbitrary event data to broadcast. */
  readonly data: Record<string, unknown>;
}

/**
 * Notify use case response — discriminated union.
 *
 * On success: ok=true with the persisted broadcast event id.
 * On failure: ok=false with an error code.
 */
export type NotifyUseCaseResponse =
  | {
      ok: true;
      data: {
        /** Id of the persisted broadcast event. */
        broadcastId: string;
      };
      error?: never;
    }
  | {
      ok: false;
      error:
        | 'INVALID_SECRET'
        | 'MISSING_TENANT'
        | 'INVALID_EVENT'
        | 'BROADCAST_FAILED';
      retryAfterMs?: number;
    };
