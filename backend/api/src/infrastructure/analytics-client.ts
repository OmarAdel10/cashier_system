import { postHogBatch } from 'daftari-backend-shared/analytics';
import type { BatchResult, PostHogEvent } from 'daftari-backend-shared/analytics';

/**
 * Analytics client wrapping PostHog batching.
 *
 * Identity fields (e.g. tenant_id inside event properties) come from verified
 * middleware context at the wiring phase; this client does not enforce authz.
 *
 * Returns the raw `BatchResult` so callers can inspect `retryable` and decide
 * whether to retry; non-ok batches are surfaced rather than swallowed.
 */
export class AnalyticsClient {
  constructor(private readonly apiKey: string) {
    if (!apiKey) {
      throw new Error('POSTHOG_API_KEY must not be empty');
    }
  }

  async batch(events: PostHogEvent[]): Promise<BatchResult> {
    return postHogBatch(this.apiKey, events);
  }
}
