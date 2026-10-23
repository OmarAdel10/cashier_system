/**
 * In-memory WebSocket event repository (temporary for Phase 3 routes).
 * Replaced by a Turso-backed adapter in Phase 4 infrastructure.
 */
import type { WebhookEventRepository } from '../../domain/repositories/webhook-event-repository';
import type { NewWebhookEvent, WebhookEvent } from '../../domain/entities/webhook-event';

export class InMemoryWebhookEventRepository implements WebhookEventRepository {
  private readonly events = new Map<string, NewWebhookEvent>();

  async insert(event: NewWebhookEvent): Promise<boolean> {
    if (this.events.has(event.transactionId)) return false;
    this.events.set(event.transactionId, { ...event });
    return true;
  }

  async findByTransactionId(transactionId: string): Promise<NewWebhookEvent | null> {
    return this.events.get(transactionId) ?? null;
  }
}
