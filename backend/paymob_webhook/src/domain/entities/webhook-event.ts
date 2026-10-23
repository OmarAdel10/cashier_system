/**
 * WebhookEvent entity.
 *
 * Represents a parsed Paymob payment webhook callback. Paymob POSTs a JSON
 * body with an `obj` containing the 20 documented transaction fields; this
 * entity holds the extracted, domain-normalized fields used to decide whether
 * a license should be issued.
 */
export interface WebhookEvent {
  /** Paymob transaction id (obj.id). */
  readonly transactionId: string;
  /** Whether the payment succeeded. */
  readonly success: boolean;
  /** Whether the transaction was refunded. */
  readonly isRefunded: boolean;
  /** Whether the transaction was voided. */
  readonly isVoided: boolean;
  /** Parsed merchant_order_id: tenant|device_hwid|billing_cycle. */
  readonly tenantId: string;
  readonly deviceHwid: string;
  readonly billingCycle: 'monthly' | 'yearly' | 'lifetime';
  /** Unix timestamp (ms) when the webhook was received. */
  readonly receivedAt: number;
}

/**
 * Input for creating a new WebhookEvent.
 */
export interface NewWebhookEvent {
  transactionId: string;
  success: boolean;
  isRefunded: boolean;
  isVoided: boolean;
  tenantId: string;
  deviceHwid: string;
  billingCycle: 'monthly' | 'yearly' | 'lifetime';
  receivedAt: number;
}

/**
 * Result of deciding whether to issue a license from a webhook event.
 */
export interface LicenseDecision {
  /** Whether a license should be issued (successful, non-refunded, non-voided payment). */
  readonly issue: boolean;
  /** Reason when issue is false, e.g. 'NOT_SUCCESSFUL', 'REFUNDED', 'VOIDED'. */
  readonly reason?: string;
}
