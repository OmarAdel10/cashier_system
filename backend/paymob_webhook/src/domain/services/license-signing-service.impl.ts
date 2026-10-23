/**
 * Default implementation of LicenseSigningService.
 *
 * Pure policy for computing the license payload from a webhook event and
 * deciding whether a license should be issued. Ed25519 signing is delegated
 * to the shared `signLicenseKey` at the application layer.
 */
import type { LicenseDecision, WebhookEvent } from '../entities/webhook-event';
import type { LicensePayload } from '../value-objects/license-payload';
import type { LicenseSigningService } from './license-signing-service';

export class LicenseSigningServiceImpl implements LicenseSigningService {
  /** Subscription length by billing cycle (milliseconds). */
  private static readonly SUBSCRIPTION_MS: Record<
    'monthly' | 'yearly' | 'lifetime',
    number
  > = {
    monthly: 30 * 24 * 60 * 60 * 1000,
    yearly: 365 * 24 * 60 * 60 * 1000,
    lifetime: 0,
  };

  /** Grace period end as an offset from subscriptionEnd (milliseconds). */
  private static readonly GRACE_MS = 7 * 24 * 60 * 60 * 1000;

  computePayload(event: WebhookEvent, now: number): LicensePayload {
    const durationMs =
      LicenseSigningServiceImpl.SUBSCRIPTION_MS[event.billingCycle as 'monthly' | 'yearly' | 'lifetime'];
    const subscriptionEnd =
      durationMs === 0 ? 0 : now + durationMs;
    const graceEnd =
      subscriptionEnd === 0 ? 0 : subscriptionEnd + LicenseSigningServiceImpl.GRACE_MS;

    return {
      tenantId: event.tenantId,
      deviceHwid: event.deviceHwid,
      subscriptionEnd,
      billingCycle: event.billingCycle,
      graceEnd,
      createdAt: now,
    };
  }

  shouldIssue(event: WebhookEvent): LicenseDecision {
    if (!event.success) {
      return { issue: false, reason: 'NOT_SUCCESSFUL' };
    }
    if (event.isRefunded) {
      return { issue: false, reason: 'REFUNDED' };
    }
    if (event.isVoided) {
      return { issue: false, reason: 'VOIDED' };
    }
    return { issue: true };
  }
}
