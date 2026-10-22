/**
 * Data Transfer Object for the /internal/notify request.
 *
 * Carries the service-binding payload from daftari-api: a tenant-scoped
 * event to fan out to the tenant's connected WebSocket sessions.
 *
 * `INVALID_SECRET` appears in the response union for documentation only —
 * it is produced by the route boundary (index.ts `X-Internal-Secret` check),
 * not by this use case.
 */
export interface NotifyUseCaseDto {
  /** Tenant the event belongs to (resolved by the API caller, trusted). */
  readonly tenantId: string;
  /** Event type, e.g. 'sale' | 'session' | 'sync'. */
  readonly event: string;
  /** Arbitrary event data to broadcast (optional at runtime). */
  readonly data?: Record<string, unknown>;
}

/**
 * Notify use case response — discriminated union.
 *
 * On success: ok=true with the persisted broadcast event id.
 * On failure: ok=false with an error code.
 *
 * `INVALID_SECRET` is listed for completeness (route-layer origin) but is
 * never returned by this use case; it is produced at the HTTP boundary.
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
        | 'INVALID_TENANT'
        | 'INVALID_EVENT'
        | 'BROADCAST_DROPPED'
        | 'BROADCAST_FAILED';
      retryAfterMs?: number;
    };
