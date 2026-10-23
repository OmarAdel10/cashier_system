/**
 * Data Transfer Object for issuing a license key.
 *
 * Carries the license payload (computed from a webhook event) and the
 * Ed25519 private key used to sign it. The route layer is responsible for
 * resolving the private key from secure storage.
 */
export interface IssueLicenseDto {
  /** License payload computed from the webhook event. */
  readonly payload: LicensePayload;
  /** Ed25519 private key (base64url) used to sign the license. */
  readonly privateKeyB64: string;
}

/**
 * IssueLicense use case response — discriminated union.
 *
 * On success: ok=true with the signed license key.
 * On failure: ok=false with an error code.
 */
export type IssueLicenseResponse =
  | {
      ok: true;
      data: {
        /** Opaque license key: base64url(signature || JSON(payload)). */
        licenseKey: string;
      };
      error?: never;
    }
  | {
      ok: false;
      error: 'KEY_INVALID' | 'SIGNING_TRANSIENT';
      retryAfterMs?: number;
    };

import type { LicensePayload } from '../../domain/value-objects/license-payload';
