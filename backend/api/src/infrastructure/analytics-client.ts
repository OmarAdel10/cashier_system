import {
  postHogBatch,
  PostHogEvent,
  BatchResult,
} from 'daftari-backend-shared/analytics';

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
  constructor(private readonly apiKey: string) {}

  async batch(events: PostHogEvent[]): Promise<BatchResult> {
    return postHogBatch(this.apiKey, events);
  }
}
