/**
 * PostHog analytics client (external service).
 *
 * Fire-and-forget event capture for webhook processing analytics. All errors
 * are swallowed — analytics must never block payment processing.
 */
export class PostHogAnalyticsService {
  constructor(
    private readonly fetchFn: typeof fetch,
    private readonly apiKey: string,
  ) {}

  async capture(payload: {
    event: string;
    distinct_id: string;
    properties: Record<string, unknown>;
    timestamp?: string;
  }): Promise<void> {
    try {
      await this.fetchFn('https://us.i.posthog.com/capture/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          api_key: this.apiKey,
          event: payload.event,
          distinct_id: payload.distinct_id,
          properties: payload.properties,
          timestamp: payload.timestamp ?? new Date().toISOString(),
        }),
      });
    } catch {
      // Analytics failures must not fail the webhook response.
    }
  }
}
