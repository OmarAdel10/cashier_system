/**
 * PostHog batch analytics — one POST per batch (server-side batching keeps
 * the PostHog API key out of the Flutter binary and amortizes network cost).
 */
import type { FetchFn } from './types';

const POSTHOG_BATCH_URL = 'https://us.i.posthog.com/batch/';

export interface PostHogEvent {
  event: string;
  properties: Record<string, unknown>;
}

export interface BatchResult {
  ok: boolean;
  /** 5xx / network error → safe to retry; 4xx → payload problem, drop. */
  retryable: boolean;
}

export async function postHogBatch(
  apiKey: string,
  events: PostHogEvent[],
  fetchFn: FetchFn = fetch,
): Promise<BatchResult> {
  try {
    const batch = events.map((e) => ({
      event: e.event,
      properties: e.properties,
      distinct_id: String(e.properties['tenant_id'] ?? 'unknown'),
      timestamp: new Date().toISOString(),
    }));
    const res = await fetchFn(POSTHOG_BATCH_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ api_key: apiKey, batch }),
    });
    if (res.ok) return { ok: true, retryable: false };
    return { ok: false, retryable: res.status >= 500 };
  } catch {
    return { ok: false, retryable: true };
  }
}
