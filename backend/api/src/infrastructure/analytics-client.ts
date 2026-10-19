import { postHogBatch, PostHogEvent } from 'daftari-backend-shared/analytics';

/**
 * Analytics client wrapping PostHog batching.
 *
 * Identity fields (e.g. tenant_id inside event properties) come from verified
 * middleware context at the wiring phase; this client does not enforce authz.
 */
export class AnalyticsClient {
  constructor(private readonly apiKey: string) {}

  async batch(events: PostHogEvent[]): Promise<void> {
    const result = await postHogBatch(this.apiKey, events);
    if (!result.ok) throw new Error('analytics batch failed');
  }
}
