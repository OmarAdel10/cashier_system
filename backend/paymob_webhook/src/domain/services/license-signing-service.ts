/**
 * Domain service for license signing business rules.
 *
 * Encapsulates pure policy for computing the license payload from a webhook
 * event and deciding the subscription/grace expiry. Ed25519 signing is
 * delegated to the shared `signLicenseKey` at the application layer.
 */
import type { WebhookEvent, LicenseDecision } from '../entities/webhook-event';
import type { LicensePayload } from '../value-objects/license-payload';

export interface LicenseSigningService {
  /**
   * Computes the license payload from a webhook event.
   *
   * @param event - Validated webhook event
   * @param now - Current timestamp in milliseconds
   * @returns the license payload to sign
   */
  computePayload(event: WebhookEvent, now: number): LicensePayload;

  /**
   * Decides whether a license should be issued for an event.
   *
   * @param event - Webhook event
   * @returns decision with issue flag and optional reason
   */
  shouldIssue(event: WebhookEvent): LicenseDecision;
}
