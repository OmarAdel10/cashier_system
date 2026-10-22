import type { BroadcastRepository } from '../../domain/repositories/broadcast-repository';
import type { NewBroadcastEvent } from '../../domain/entities/broadcast-event';

/**
 * In-memory broadcast event repository.
 *
 * Temporary implementation for Phase 3 (route refactoring). Replaced by a
 * Turso-backed adapter in Phase 4.
 */
export class InMemoryBroadcastRepository implements BroadcastRepository {
  private readonly events = new Map<string, NewBroadcastEvent>();

  async insert(event: NewBroadcastEvent): Promise<boolean> {
    if (this.events.has(event.id)) return false;
    this.events.set(event.id, { ...event });
    return true;
  }

  async getRecentForTenant(
    tenantId: string,
    limit: number,
  ): Promise<Array<NewBroadcastEvent>> {
    return Array.from(this.events.values())
      .filter((e) => e.tenantId === tenantId)
      .sort((a, b) => b.createdAt - a.createdAt)
      .slice(0, limit);
  }
}
