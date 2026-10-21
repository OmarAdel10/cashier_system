import type { BroadcastService } from './broadcast-service';
import type { BroadcastPayload } from '../value-objects/broadcast-payload';

/**
 * Default implementation of BroadcastService.
 *
 * Pure policy: build a canonical payload and decide whether to fan out.
 */
export class BroadcastServiceImpl implements BroadcastService {
  buildPayload(
    type: string,
    tenantId: string,
    data: Record<string, unknown>,
    createdAt: number,
  ): BroadcastPayload {
    return {
      type: (type ?? '').trim(),
      tenantId: (tenantId ?? '').trim(),
      data: data ?? {},
      createdAt,
    };
  }

  shouldBroadcast(payload: BroadcastPayload): boolean {
    // Drop events with no resolvable tenant — they cannot be routed to a DO.
    if (!payload.tenantId) return false;
    // Drop events with an empty type — they carry no semantic meaning.
    if (!payload.type) return false;
    return true;
  }
}
