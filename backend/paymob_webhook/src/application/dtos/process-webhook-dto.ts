/**
 * Data Transfer Object for processing a Paymob webhook callback.
 *
 * Carries the verified webhook event and the HMAC secret used to validate
 * the request signature. The route layer is responsible for extracting these
 * from the HTTP request (query params, headers, body) and verifying the
 * HMAC before constructing this DTO.
 */
export interface ProcessWebhookDto {
  /** Validated webhook event (HMAC already checked at route boundary). */
  readonly event: WebhookEvent;
  /** HMAC signature from the Paymob callback query parameters. */
  readonly signatureHex: string;
  /** Shared HMAC secret used to verify the webhook signature. */
  readonly hmacSecret: string;
}

/**
 * ProcessWebhook use case response — discriminated union.
 *
 * On success: ok=true with the computed license payload and issue decision.
 * On failure: ok=false with an error code.
 */
export type ProcessWebhookResponse =
  | {
      ok: true;
      data: {
        /** License payload computed from the webhook event (to be signed). */
        payload: LicensePayload;
        /** Whether a license should be issued for this event. */
        decision: LicenseDecision;
      };
      error?: never;
    }
  | {
      ok: false;
      error:
        | 'INVALID_HMAC'
        | 'DUPLICATE_EVENT'
        | 'INVALID_EVENT'
        | 'PROCESSING_FAILED';
      retryAfterMs?: number;
    };

import type { WebhookEvent } from '../../domain/entities/webhook-event';
import type { LicensePayload } from '../../domain/value-objects/license-payload';
import type { LicenseDecision } from '../../domain/entities/webhook-event';
