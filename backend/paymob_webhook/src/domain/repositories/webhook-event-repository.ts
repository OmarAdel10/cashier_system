/**
 * Repository interface for webhook event persistence.
 *
 * Records processed Paymob webhook events so they can be audited and
 * duplicate processing can be detected.
 */
import { NewWebhookEvent } from '../entities/webhook-event';

export interface WebhookEventRepository {
  /**
   * Inserts a new webhook event.
   *
   * @param event - Event to insert
   * @returns true if inserted, false if an event with this transaction id
   *          already exists (idempotency guard against duplicate callbacks)
   */
  insert(event: NewWebhookEvent): Promise<boolean>;

  /**
   * Gets an event by Paymob transaction id.
   *
   * @param transactionId - Paymob transaction id
   * @returns Event or null if not found
   */
  findByTransactionId(transactionId: string): Promise<NewWebhookEvent | null>;
}
