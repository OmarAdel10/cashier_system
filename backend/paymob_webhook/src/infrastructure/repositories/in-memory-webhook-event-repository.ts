/**
 * In-memory WebSocket event repository (temporary for Phase 3 routes).
 * Replaced by a Turso-backed adapter in Phase 4 infrastructure.
 */
import type { WebhookEventRepository } from '../../domain/repositories/webhook-event-repository';
import type { NewWebhookEvent, WebhookEvent } from '../../domain/entities/webhook-event';

export class InMemoryWebhookEventRepository implements WebhookEventRepository {
  private readonly events = new Map<string, NewWebhookEvent>();
  private readonly maxSize = 10_000;

  async insert(event: NewWebhookEvent): Promise<boolean> {
    if (this.events.has(event.transactionId)) return false;
    if (this.events.size >= this.maxSize) {
      // Evict oldest entry to prevent unbounded growth.
      this.events.delete(this.events.keys().next().value!);
    }
    this.events.set(event.transactionId, { ...event });
    return true;
  }

  async findByTransactionId(transactionId: string): Promise<NewWebhookEvent | null> {
    return this.events.get(transactionId) ?? null;
  }

  /**
   * Removes events older than maxAgeMs. Returns number of removed events.
   */
  sweep(maxAgeMs: number): number {
    const now = Date.now();
    let removed = 0;
    for (const [key, event] of this.events) {
      if (now - event.receivedAt > maxAgeMs) {
        this.events.delete(key);
        removed++;
      }
    }
    return removed;
  }
}
