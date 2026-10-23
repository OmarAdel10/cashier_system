/**
 * Turso-backed WebhookEventRepository adapter.
 *
 * Persists processed Paymob webhook events to a `webhook_events` table for
 * idempotency (duplicate-callback protection) and audit. Uses `ON CONFLICT
 * (transaction_id) DO NOTHING` so concurrent duplicate callbacks are rejected
 * safely without throwing.
 */
import { TursoDb } from '../../../../shared/src/turso';
import type { NewWebhookEvent } from '../../domain/entities/webhook-event';
import type { WebhookEventRepository } from '../../domain/repositories/webhook-event-repository';

export class TursoWebhookEventRepository implements WebhookEventRepository {
  constructor(private readonly db: TursoDb) {}

  async insert(event: NewWebhookEvent): Promise<boolean> {
    const res = await this.db.exec(
      `INSERT INTO webhook_events (
        transaction_id, success, is_refunded, is_voided,
        tenant_id, device_hwid, billing_cycle, received_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT (transaction_id) DO NOTHING`,
      [
        event.transactionId,
        event.success ? 1 : 0,
        event.isRefunded ? 1 : 0,
        event.isVoided ? 1 : 0,
        event.tenantId,
        event.deviceHwid,
        event.billingCycle,
        event.receivedAt,
      ],
    );
    return (res.rowsAffected ?? 0) > 0;
  }

  async findByTransactionId(transactionId: string): Promise<NewWebhookEvent | null> {
    const res = await this.db.exec(
      `SELECT * FROM webhook_events WHERE transaction_id = ?`,
      [transactionId],
    );
    const row = res.rows[0] as unknown as Record<string, unknown> | undefined;
    if (!row) return null;
    return {
      transactionId: String(row['transaction_id']),
      success: Number(row['success']) === 1,
      isRefunded: Number(row['is_refunded']) === 1,
      isVoided: Number(row['is_voided']) === 1,
      tenantId: String(row['tenant_id']),
      deviceHwid: String(row['device_hwid']),
      billingCycle: String(row['billing_cycle']) as 'monthly' | 'yearly' | 'lifetime',
      receivedAt: Number(row['received_at']),
    };
  }
}
